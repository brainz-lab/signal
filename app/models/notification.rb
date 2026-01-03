class Notification < ApplicationRecord
  belongs_to :project
  belongs_to :alert, optional: true
  belongs_to :incident, optional: true
  belongs_to :notification_channel

  validates :notification_type, presence: true
  validates :status, presence: true, inclusion: { in: %w[pending sent failed skipped] }
  validates :project_id, presence: true

  scope :pending, -> { where(status: "pending") }
  scope :sent, -> { where(status: "sent") }
  scope :failed, -> { where(status: "failed") }
  scope :for_project, ->(project_id) { where(project_id: project_id) }
end
