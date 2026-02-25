require "rails_helper"

RSpec.describe NotificationChannel, type: :model do
  # ────────────────────────────────
  # Associations
  # ────────────────────────────────
  it { is_expected.to belong_to(:project) }
  it { is_expected.to have_many(:notifications).dependent(:destroy) }

  # ────────────────────────────────
  # Validations
  # ────────────────────────────────
  it { is_expected.to validate_presence_of(:name) }
  it { is_expected.to validate_presence_of(:slug) }
  it { is_expected.to validate_presence_of(:channel_type) }
  it {
    is_expected.to validate_inclusion_of(:channel_type)
      .in_array(%w[slack pagerduty email webhook discord teams opsgenie])
  }

  describe "slug uniqueness" do
    it "is scoped to project" do
      project = create(:project)
      create(:notification_channel, project: project, slug: "my-channel")
      dup = build(:notification_channel, project: project, slug: "my-channel")
      expect(dup).not_to be_valid
    end

    it "allows same slug across projects" do
      create(:notification_channel, slug: "ops-alerts")
      channel = build(:notification_channel, slug: "ops-alerts")
      expect(channel).to be_valid
    end
  end

  # ────────────────────────────────
  # Callbacks
  # ────────────────────────────────
  describe "before_validation :generate_slug" do
    it "generates slug from name" do
      channel = create(:notification_channel, name: "Ops Slack", slug: nil)
      expect(channel.slug).to eq("ops-slack")
    end

    it "preserves an existing slug" do
      channel = create(:notification_channel, name: "Ops Slack", slug: "custom-slug")
      expect(channel.slug).to eq("custom-slug")
    end
  end

  # ────────────────────────────────
  # #notifier factory method
  # ────────────────────────────────
  describe "#notifier" do
    it "returns Notifiers::Slack for slack channels" do
      channel = build(:notification_channel, :slack)
      expect(channel.notifier).to be_a(Notifiers::Slack)
    end

    it "returns Notifiers::Webhook for webhook channels" do
      channel = build(:notification_channel, :webhook)
      expect(channel.notifier).to be_a(Notifiers::Webhook)
    end

    it "returns Notifiers::Email for email channels" do
      channel = build(:notification_channel, :email)
      expect(channel.notifier).to be_a(Notifiers::Email)
    end

    it "returns Notifiers::Pagerduty for pagerduty channels" do
      channel = build(:notification_channel, :pagerduty)
      expect(channel.notifier).to be_a(Notifiers::Pagerduty)
    end
  end

  # ────────────────────────────────
  # Scopes
  # ────────────────────────────────
  describe "scopes" do
    let(:project) { create(:project) }
    let!(:enabled_ch)  { create(:notification_channel, project: project) }
    let!(:disabled_ch) { create(:notification_channel, project: project, :disabled) }

    it ".enabled returns only enabled channels" do
      expect(NotificationChannel.enabled).to include(enabled_ch)
      expect(NotificationChannel.enabled).not_to include(disabled_ch)
    end

    it ".for_project scopes to a project" do
      other = create(:notification_channel)
      expect(NotificationChannel.for_project(project.id)).to include(enabled_ch)
      expect(NotificationChannel.for_project(project.id)).not_to include(other)
    end
  end

  # ────────────────────────────────
  # Encryption
  # ────────────────────────────────
  describe "config encryption" do
    it "persists and retrieves config as a Hash" do
      channel = create(:notification_channel, :slack)
      reloaded = NotificationChannel.find(channel.id)
      expect(reloaded.config["webhook_url"]).to include("hooks.slack.com")
    end
  end
end
