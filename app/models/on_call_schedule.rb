class OnCallSchedule < ApplicationRecord
  belongs_to :project

  validates :name, presence: true
  validates :slug, presence: true, uniqueness: { scope: :project_id }
  validates :schedule_type, presence: true, inclusion: { in: %w[weekly custom] }
  validates :project_id, presence: true

  before_validation :generate_slug, on: :create

  scope :enabled, -> { where(enabled: true) }
  scope :for_project, ->(project_id) { where(project_id: project_id) }

  def current_on_call_user
    return current_on_call if current_shift_end.nil? || current_shift_end > Time.current

    update_current_on_call!
    current_on_call
  end

  def update_current_on_call!
    case schedule_type
    when "weekly"
      update_weekly_on_call!
    when "custom"
      update_rotation_on_call!
    end
  end

  private

  def generate_slug
    self.slug ||= name&.parameterize
  end

  def update_weekly_on_call!
    day = Time.current.strftime("%A").downcase
    schedule = weekly_schedule[day]
    return unless schedule

    update!(
      current_on_call: schedule["user"],
      current_shift_start: Time.current.beginning_of_day,
      current_shift_end: Time.current.end_of_day
    )
  end

  def update_rotation_on_call!
    return if members.empty?

    days_since_start = (Time.current.to_date - rotation_start.to_date).to_i
    rotation_days = rotation_type == "daily" ? 1 : 7
    current_index = (days_since_start / rotation_days) % members.length

    update!(
      current_on_call: members[current_index],
      current_shift_start: Time.current.beginning_of_day,
      current_shift_end: rotation_days.days.from_now.beginning_of_day
    )
  end
end
