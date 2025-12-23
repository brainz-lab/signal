class NotificationChannel < ApplicationRecord
  has_many :notifications, dependent: :destroy

  validates :name, presence: true
  validates :slug, presence: true, uniqueness: { scope: :project_id }
  validates :channel_type, presence: true, inclusion: {
    in: %w[slack pagerduty email webhook discord teams opsgenie]
  }
  validates :project_id, presence: true

  before_validation :generate_slug, on: :create
  encrypts :config

  scope :enabled, -> { where(enabled: true) }
  scope :for_project, ->(project_id) { where(project_id: project_id) }

  def notifier
    case channel_type
    when 'slack' then Notifiers::Slack.new(self)
    when 'pagerduty' then Notifiers::Pagerduty.new(self)
    when 'email' then Notifiers::Email.new(self)
    when 'webhook' then Notifiers::Webhook.new(self)
    when 'discord' then Notifiers::Discord.new(self)
    when 'teams' then Notifiers::Teams.new(self)
    when 'opsgenie' then Notifiers::Opsgenie.new(self)
    end
  end

  def send_notification!(alert:, notification_type:)
    notifier.send!(alert: alert, notification_type: notification_type)
  end

  def test!
    result = notifier.test!
    update!(
      last_tested_at: Time.current,
      last_test_status: result[:success] ? 'success' : 'failed',
      verified: result[:success]
    )
    result
  end

  private

  def generate_slug
    self.slug ||= name&.parameterize
  end
end
