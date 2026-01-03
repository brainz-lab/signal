class AlertHistory < ApplicationRecord
  belongs_to :project
  belongs_to :alert_rule

  validates :timestamp, presence: true
  validates :state, presence: true, inclusion: { in: %w[ok pending firing] }
  validates :project_id, presence: true

  scope :for_project, ->(project_id) { where(project_id: project_id) }
  scope :recent, -> { order(timestamp: :desc) }
end
