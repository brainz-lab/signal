class Project < ApplicationRecord
  has_many :alerts, dependent: :destroy
  has_many :alert_rules, dependent: :destroy
  has_many :incidents, dependent: :destroy
  has_many :notification_channels, dependent: :destroy
  has_many :escalation_policies, dependent: :destroy
  has_many :on_call_schedules, dependent: :destroy
  has_many :maintenance_windows, dependent: :destroy

  validates :platform_project_id, presence: true, uniqueness: true

  def self.find_or_create_for_platform!(platform_project_id:, name: nil, environment: "live")
    find_or_create_by!(platform_project_id: platform_project_id) do |p|
      p.name = name
      p.environment = environment
    end
  end
end
