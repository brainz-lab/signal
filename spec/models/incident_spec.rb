require 'rails_helper'

RSpec.describe Incident, type: :model do
  describe 'associations' do
    it { should have_many(:alerts).dependent(:nullify) }
    it { should have_many(:notifications).dependent(:destroy) }
  end

  describe 'validations' do
    it { should validate_presence_of(:title) }
    it { should validate_presence_of(:project_id) }
    it { should validate_inclusion_of(:status).in_array(%w[triggered acknowledged resolved]) }
    it { should validate_inclusion_of(:severity).in_array(%w[info warning critical]) }
  end

  describe 'scopes' do
    let(:project_id) { SecureRandom.uuid }
    let!(:triggered_incident) { create(:incident, status: 'triggered', project_id: project_id) }
    let!(:acknowledged_incident) { create(:incident, :acknowledged, project_id: project_id) }
    let!(:resolved_incident) { create(:incident, :resolved, project_id: project_id) }
    let!(:critical_incident) { create(:incident, :critical, project_id: project_id) }

    describe '.open' do
      it 'returns triggered and acknowledged incidents' do
        expect(Incident.open).to include(triggered_incident, acknowledged_incident)
        expect(Incident.open).not_to include(resolved_incident)
      end
    end

    describe '.resolved' do
      it 'returns only resolved incidents' do
        expect(Incident.resolved).to contain_exactly(resolved_incident)
      end
    end

    describe '.by_severity' do
      it 'returns incidents with specific severity' do
        expect(Incident.by_severity('critical')).to include(critical_incident)
        expect(Incident.by_severity('warning')).to include(triggered_incident)
      end
    end

    describe '.recent' do
      it 'orders incidents by triggered_at descending' do
        expect(Incident.recent.first).to eq(critical_incident)
      end
    end

    describe '.for_project' do
      let(:other_project_id) { SecureRandom.uuid }
      let!(:other_incident) { create(:incident, project_id: other_project_id) }

      it 'returns incidents for specific project' do
        expect(Incident.for_project(project_id)).to include(triggered_incident)
        expect(Incident.for_project(project_id)).not_to include(other_incident)
      end
    end
  end

  describe '#acknowledge!' do
    let(:incident) { create(:incident) }

    it 'updates status to acknowledged' do
      incident.acknowledge!(by: 'user1')
      expect(incident.status).to eq('acknowledged')
    end

    it 'sets acknowledged_at and acknowledged_by' do
      freeze_time do
        incident.acknowledge!(by: 'user1')
        expect(incident.acknowledged_at).to be_within(1.second).of(Time.current)
        expect(incident.acknowledged_by).to eq('user1')
      end
    end

    it 'adds timeline event' do
      incident.acknowledge!(by: 'user1')
      timeline_event = incident.timeline.last
      expect(timeline_event['type']).to eq('acknowledged')
      expect(timeline_event['by']).to eq('user1')
    end

    context 'when already resolved' do
      let(:incident) { create(:incident, :resolved) }

      it 'does not change status' do
        expect {
          incident.acknowledge!(by: 'user1')
        }.not_to change(incident, :status)
      end
    end
  end

  describe '#resolve!' do
    let(:incident) { create(:incident) }

    it 'updates status to resolved' do
      incident.resolve!(by: 'user1')
      expect(incident.status).to eq('resolved')
    end

    it 'sets resolved_at and resolved_by' do
      freeze_time do
        incident.resolve!(by: 'user1', note: 'Fixed')
        expect(incident.resolved_at).to be_within(1.second).of(Time.current)
        expect(incident.resolved_by).to eq('user1')
        expect(incident.resolution_note).to eq('Fixed')
      end
    end

    it 'adds timeline event with note' do
      incident.resolve!(by: 'user1', note: 'Issue resolved')
      timeline_event = incident.timeline.last
      expect(timeline_event['type']).to eq('resolved')
      expect(timeline_event['by']).to eq('user1')
      expect(timeline_event['message']).to eq('Issue resolved')
    end
  end

  describe '#add_timeline_event' do
    let(:incident) { create(:incident) }

    it 'adds event to timeline' do
      initial_count = incident.timeline.count
      incident.add_timeline_event(
        type: 'comment',
        message: 'Investigating issue',
        by: 'user1',
        data: { severity_changed: true }
      )

      expect(incident.timeline.count).to eq(initial_count + 1)
      event = incident.timeline.last
      expect(event['type']).to eq('comment')
      expect(event['message']).to eq('Investigating issue')
      expect(event['by']).to eq('user1')
      expect(event['severity_changed']).to be true
      expect(event['at']).to be_present
    end

    it 'removes nil values from event' do
      incident.add_timeline_event(type: 'update', message: nil)
      event = incident.timeline.last
      expect(event.key?('message')).to be false
    end
  end

  describe '#duration' do
    let(:incident) { create(:incident, triggered_at: 2.hours.ago) }

    context 'when not resolved' do
      it 'returns duration from trigger to now' do
        expect(incident.duration).to be_within(1).of(7200)
      end
    end

    context 'when resolved' do
      before { incident.update!(resolved_at: 1.hour.ago) }

      it 'returns duration from trigger to resolution' do
        expect(incident.duration).to be_within(1).of(3600)
      end
    end
  end
end
