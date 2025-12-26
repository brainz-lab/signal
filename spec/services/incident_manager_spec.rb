require 'rails_helper'

RSpec.describe IncidentManager do
  let(:project_id) { SecureRandom.uuid }
  let(:alert_rule) { create(:alert_rule, project_id: project_id, name: 'High CPU') }
  let(:alert) { create(:alert, :firing, alert_rule: alert_rule, project_id: project_id) }
  let(:manager) { described_class.new(alert) }

  describe '#fire!' do
    context 'when no incident exists' do
      it 'creates a new incident' do
        expect {
          manager.fire!
        }.to change(Incident, :count).by(1)

        incident = Incident.last
        expect(incident.project_id).to eq(project_id)
        expect(incident.title).to eq('High CPU')
        expect(incident.severity).to eq(alert_rule.severity)
        expect(incident.status).to eq('triggered')
      end

      it 'associates alert with the incident' do
        incident = manager.fire!
        alert.reload
        expect(alert.incident).to eq(incident)
      end

      it 'adds timeline event' do
        incident = manager.fire!
        expect(incident.timeline.length).to eq(2) # Initial + alert_fired

        event = incident.timeline.last
        expect(event['type']).to eq('alert_fired')
        expect(event['message']).to include('High CPU')
        expect(event['data']['alert_id']).to eq(alert.id)
      end
    end

    context 'when an open incident exists for the rule' do
      let!(:existing_incident) do
        create(:incident, project_id: project_id)
      end
      let!(:other_alert) do
        create(:alert, :firing,
          alert_rule: alert_rule,
          incident: existing_incident,
          project_id: project_id
        )
      end

      it 'reuses the existing incident' do
        expect {
          manager.fire!
        }.not_to change(Incident, :count)

        alert.reload
        expect(alert.incident).to eq(existing_incident)
      end

      it 'adds timeline event to existing incident' do
        initial_count = existing_incident.timeline.count
        manager.fire!

        existing_incident.reload
        expect(existing_incident.timeline.count).to eq(initial_count + 1)
      end
    end

    context 'when only resolved incidents exist' do
      let!(:resolved_incident) do
        create(:incident, :resolved, project_id: project_id)
      end
      let!(:other_alert) do
        create(:alert, :resolved,
          alert_rule: alert_rule,
          incident: resolved_incident,
          project_id: project_id
        )
      end

      it 'creates a new incident' do
        expect {
          manager.fire!
        }.to change(Incident, :count).by(1)

        alert.reload
        expect(alert.incident).not_to eq(resolved_incident)
      end
    end
  end

  describe '#resolve!' do
    context 'when alert has an incident' do
      let(:incident) { create(:incident, project_id: project_id) }

      before do
        alert.update!(incident: incident)
      end

      it 'adds resolution timeline event' do
        initial_count = incident.timeline.count
        manager.resolve!

        incident.reload
        expect(incident.timeline.count).to eq(initial_count + 1)

        event = incident.timeline.last
        expect(event['type']).to eq('alert_resolved')
        expect(event['message']).to include(alert_rule.name)
      end

      context 'when all alerts are resolved' do
        before do
          # Create another alert for the same incident
          create(:alert, :resolved,
            incident: incident,
            alert_rule: alert_rule,
            project_id: project_id
          )
        end

        it 'resolves the incident' do
          expect(incident).to receive(:resolve!)
          manager.resolve!
        end
      end

      context 'when other alerts are still firing' do
        before do
          create(:alert, :firing,
            incident: incident,
            alert_rule: alert_rule,
            project_id: project_id
          )
        end

        it 'does not resolve the incident' do
          expect(incident).not_to receive(:resolve!)
          manager.resolve!
        end
      end
    end

    context 'when alert has no incident' do
      it 'does nothing' do
        expect {
          manager.resolve!
        }.not_to change(Incident, :count)
      end
    end
  end
end
