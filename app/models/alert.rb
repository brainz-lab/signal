class Alert < ApplicationRecord
  belongs_to :alert_rule
  belongs_to :incident, optional: true
  has_many :notifications, dependent: :destroy

  validates :fingerprint, presence: true
  validates :state, presence: true, inclusion: { in: %w[pending firing resolved] }
  validates :project_id, presence: true

  scope :active, -> { where(state: %w[pending firing]) }
  scope :firing, -> { where(state: "firing") }
  scope :pending, -> { where(state: "pending") }
  scope :resolved, -> { where(state: "resolved") }
  scope :unacknowledged, -> { where(acknowledged: false) }
  scope :recent, -> { order(started_at: :desc) }
  scope :for_project, ->(project_id) { where(project_id: project_id) }

  def fire!
    update!(
      state: "firing",
      last_fired_at: Time.current
    )

    # Create or update incident
    IncidentManager.new(self).fire!

    # Send notifications
    notify!(:alert_fired)
  end

  def resolve!
    update!(
      state: "resolved",
      resolved_at: Time.current
    )

    # Update incident
    IncidentManager.new(self).resolve!

    # Send resolution notification
    notify!(:alert_resolved)
  end

  def acknowledge!(by:, note: nil)
    update!(
      acknowledged: true,
      acknowledged_at: Time.current,
      acknowledged_by: by,
      acknowledgment_note: note
    )

    # Update incident
    incident&.acknowledge!(by: by)
  end

  def duration
    end_time = resolved_at || Time.current
    end_time - started_at
  end

  def duration_human
    ActiveSupport::Duration.build(duration.to_i).inspect
  end

  def severity
    alert_rule.severity
  end

  private

  def notify!(notification_type)
    return if alert_rule.muted?

    alert_rule.notification_channels.each do |channel|
      NotificationJob.perform_later(
        channel_id: channel.id,
        alert_id: id,
        notification_type: notification_type.to_s
      )
    end

    update!(
      last_notified_at: Time.current,
      notification_count: notification_count + 1
    )
  end
end
