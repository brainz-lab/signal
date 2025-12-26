require 'rails_helper'

RSpec.describe AlertManager do
  let(:project_id) { SecureRandom.uuid }
  let(:rule) { create(:alert_rule, project_id: project_id, pending_period: 0, resolve_period: 300) }
  let(:manager) { described_class.new(rule) }
  let(:fingerprint) { Digest::SHA256.hexdigest('test-fingerprint') }

  describe '#process' do
    context 'with firing state' do
      let(:result) do
        {
          state: 'firing',
          value: 150.0,
          threshold: 100.0,
          fingerprint: fingerprint,
          labels: { host: 'server-01' }
        }
      end

      context 'when alert does not exist' do
        it 'creates a new pending alert' do
          expect {
            manager.process(result)
          }.to change(Alert, :count).by(1)

          alert = Alert.last
          expect(alert.state).to eq('pending')
          expect(alert.fingerprint).to eq(fingerprint)
          expect(alert.current_value).to eq(150.0)
        end
      end

      context 'when alert is pending and pending period elapsed' do
        let!(:alert) do
          create(:alert,
            alert_rule: rule,
            fingerprint: fingerprint,
            state: 'pending',
            started_at: 2.minutes.ago,
            project_id: project_id
          )
        end

        before do
          rule.update!(pending_period: 60) # 60 seconds
        end

        it 'fires the alert' do
          expect(alert).to receive(:fire!)
          manager.process(result)
        end
      end

      context 'when alert is pending but pending period not elapsed' do
        let!(:alert) do
          create(:alert,
            alert_rule: rule,
            fingerprint: fingerprint,
            state: 'pending',
            started_at: 30.seconds.ago,
            project_id: project_id
          )
        end

        before do
          rule.update!(pending_period: 60)
        end

        it 'updates but does not fire the alert' do
          expect(alert).not_to receive(:fire!)
          manager.process(result)
          alert.reload
          expect(alert.state).to eq('pending')
          expect(alert.current_value).to eq(150.0)
        end
      end

      context 'when alert is already firing' do
        let!(:alert) do
          create(:alert, :firing,
            alert_rule: rule,
            fingerprint: fingerprint,
            project_id: project_id
          )
        end

        it 'updates last_fired_at' do
          freeze_time do
            manager.process(result)
            alert.reload
            expect(alert.last_fired_at).to be_within(1.second).of(Time.current)
          end
        end
      end

      context 'when alert is resolved' do
        let!(:alert) do
          create(:alert, :resolved,
            alert_rule: rule,
            fingerprint: fingerprint,
            project_id: project_id
          )
        end

        it 'creates a new pending alert instance' do
          manager.process(result)
          alert.reload

          expect(alert.state).to eq('pending')
          expect(alert.resolved_at).to be_nil
          expect(alert.acknowledged).to be false
        end
      end
    end

    context 'with ok state' do
      let(:result) { { state: 'ok', fingerprint: fingerprint } }

      context 'when alert is firing and ok long enough' do
        let!(:alert) do
          create(:alert, :firing,
            alert_rule: rule,
            fingerprint: fingerprint,
            project_id: project_id
          )
        end

        before do
          # Create history showing OK state for resolve period
          create_list(:alert_history, 3,
            alert_rule: rule,
            fingerprint: fingerprint,
            state: 'ok',
            timestamp: 2.minutes.ago,
            project_id: project_id
          )
        end

        it 'resolves the alert' do
          expect(alert).to receive(:resolve!)
          manager.process(result)
        end
      end

      context 'when alert is firing but not ok long enough' do
        let!(:alert) do
          create(:alert, :firing,
            alert_rule: rule,
            fingerprint: fingerprint,
            project_id: project_id
          )
        end

        before do
          # Mix of OK and firing states
          create(:alert_history,
            alert_rule: rule,
            fingerprint: fingerprint,
            state: 'ok',
            timestamp: 1.minute.ago,
            project_id: project_id
          )
          create(:alert_history,
            alert_rule: rule,
            fingerprint: fingerprint,
            state: 'firing',
            timestamp: 2.minutes.ago,
            project_id: project_id
          )
        end

        it 'does not resolve the alert' do
          expect(alert).not_to receive(:resolve!)
          manager.process(result)
        end
      end

      context 'when alert is pending' do
        let!(:alert) do
          create(:alert,
            alert_rule: rule,
            fingerprint: fingerprint,
            state: 'pending',
            project_id: project_id
          )
        end

        it 'destroys the alert' do
          expect {
            manager.process(result)
          }.to change(Alert, :count).by(-1)
        end
      end

      context 'when alert does not exist' do
        it 'does nothing' do
          expect {
            manager.process(result)
          }.not_to change(Alert, :count)
        end
      end
    end
  end
end
