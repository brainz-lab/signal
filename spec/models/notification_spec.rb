require 'rails_helper'

RSpec.describe Notification, type: :model do
  describe 'associations' do
    it { should belong_to(:alert).optional }
    it { should belong_to(:incident).optional }
    it { should belong_to(:notification_channel) }
  end

  describe 'validations' do
    it { should validate_presence_of(:notification_type) }
    it { should validate_presence_of(:status) }
    it { should validate_presence_of(:project_id) }
    it { should validate_inclusion_of(:status).in_array(%w[pending sent failed skipped]) }
  end

  describe 'scopes' do
    let(:project_id) { SecureRandom.uuid }
    let!(:pending_notification) { create(:notification, status: 'pending', project_id: project_id) }
    let!(:sent_notification) { create(:notification, :sent, project_id: project_id) }
    let!(:failed_notification) { create(:notification, :failed, project_id: project_id) }
    let!(:skipped_notification) { create(:notification, :skipped, project_id: project_id) }

    describe '.pending' do
      it 'returns only pending notifications' do
        expect(Notification.pending).to contain_exactly(pending_notification)
      end
    end

    describe '.sent' do
      it 'returns only sent notifications' do
        expect(Notification.sent).to contain_exactly(sent_notification)
      end
    end

    describe '.failed' do
      it 'returns only failed notifications' do
        expect(Notification.failed).to contain_exactly(failed_notification)
      end
    end

    describe '.for_project' do
      let(:other_project_id) { SecureRandom.uuid }
      let!(:other_notification) { create(:notification, project_id: other_project_id) }

      it 'returns notifications for specific project' do
        expect(Notification.for_project(project_id)).to include(pending_notification)
        expect(Notification.for_project(project_id)).not_to include(other_notification)
      end
    end
  end
end
