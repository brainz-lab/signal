class Incident < ApplicationRecord
  belongs_to :project
  has_many :alerts, dependent: :nullify
  has_many :notifications, dependent: :destroy

  validates :title, presence: true
  validates :status, inclusion: { in: %w[triggered acknowledged resolved] }
  validates :severity, inclusion: { in: %w[info warning critical] }
  validates :project_id, presence: true

  scope :open, -> { where(status: %w[triggered acknowledged]) }
  scope :resolved, -> { where(status: "resolved") }
  scope :by_severity, ->(sev) { where(severity: sev) }
  scope :recent, -> { order(triggered_at: :desc) }
  scope :for_project, ->(project_id) { where(project_id: project_id) }

  def acknowledge!(by:)
    return if status == "resolved"

    update!(
      status: "acknowledged",
      acknowledged_at: Time.current,
      acknowledged_by: by
    )

    add_timeline_event(type: "acknowledged", by: by)
  end

  def resolve!(by: nil, note: nil)
    update!(
      status: "resolved",
      resolved_at: Time.current,
      resolved_by: by,
      resolution_note: note
    )

    add_timeline_event(type: "resolved", by: by, message: note)
  end

  def add_timeline_event(type:, message: nil, by: nil, data: {})
    event = {
      at: Time.current.iso8601,
      type: type,
      message: message,
      by: by
    }.merge(data).compact

    update!(timeline: timeline + [ event ])
  end

  def duration
    end_time = resolved_at || Time.current
    end_time - triggered_at
  end
end
