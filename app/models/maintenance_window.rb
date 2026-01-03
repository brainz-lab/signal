class MaintenanceWindow < ApplicationRecord
  belongs_to :project

  validates :name, presence: true
  validates :starts_at, presence: true
  validates :ends_at, presence: true
  validates :project_id, presence: true
  validate :ends_after_starts

  scope :active, -> { where(active: true) }
  scope :current, -> { where("starts_at <= ? AND ends_at >= ?", Time.current, Time.current) }
  scope :for_project, ->(project_id) { where(project_id: project_id) }

  def currently_active?
    active? && starts_at <= Time.current && ends_at >= Time.current
  end

  def covers_rule?(rule_id)
    return true if rule_ids.empty?
    rule_ids.include?(rule_id)
  end

  private

  def ends_after_starts
    return unless starts_at && ends_at
    errors.add(:ends_at, "must be after starts_at") if ends_at <= starts_at
  end
end
