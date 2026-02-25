require "rails_helper"

RSpec.describe Notification, type: :model do
  # ────────────────────────────────
  # Associations
  # ────────────────────────────────
  it { is_expected.to belong_to(:project) }
  it { is_expected.to belong_to(:alert).optional }
  it { is_expected.to belong_to(:incident).optional }
  it { is_expected.to belong_to(:notification_channel) }

  # ────────────────────────────────
  # Validations
  # ────────────────────────────────
  it { is_expected.to validate_presence_of(:notification_type) }
  it { is_expected.to validate_presence_of(:status) }
  it { is_expected.to validate_inclusion_of(:status).in_array(%w[pending sent failed skipped]) }

  # ────────────────────────────────
  # Scopes
  # ────────────────────────────────
  describe "scopes" do
    let!(:pending_n)  { create(:notification, :pending) }
    let!(:sent_n)     { create(:notification, :sent) }
    let!(:failed_n)   { create(:notification, :failed) }

    it ".pending returns only pending notifications" do
      expect(Notification.pending).to include(pending_n)
      expect(Notification.pending).not_to include(sent_n, failed_n)
    end

    it ".sent returns only sent notifications" do
      expect(Notification.sent).to include(sent_n)
      expect(Notification.sent).not_to include(pending_n, failed_n)
    end

    it ".failed returns only failed notifications" do
      expect(Notification.failed).to include(failed_n)
      expect(Notification.failed).not_to include(pending_n, sent_n)
    end

    it ".for_project scopes to the given project" do
      project = create(:project)
      channel = create(:notification_channel, project: project)
      scoped  = create(:notification, project: project, notification_channel: channel)
      expect(Notification.for_project(project.id)).to include(scoped)
      expect(Notification.for_project(project.id)).not_to include(pending_n)
    end
  end

  # ────────────────────────────────
  # Defaults
  # ────────────────────────────────
  describe "defaults" do
    it "initializes payload and response as empty hashes" do
      notification = create(:notification)
      expect(notification.payload).to eq({})
      expect(notification.response).to eq({})
    end

    it "initializes retry_count to 0" do
      notification = create(:notification)
      expect(notification.retry_count).to eq(0)
    end
  end
end
