class Project < ApplicationRecord
  has_many :alerts, dependent: :destroy
  has_many :alert_rules, dependent: :destroy
  has_many :incidents, dependent: :destroy
  has_many :notification_channels, dependent: :destroy
  has_many :escalation_policies, dependent: :destroy
  has_many :on_call_schedules, dependent: :destroy
  has_many :maintenance_windows, dependent: :destroy

  validates :platform_project_id, presence: true, uniqueness: true

  scope :active, -> { where(archived_at: nil) }
  scope :archived, -> { where.not(archived_at: nil) }

  before_create :generate_keys

  def self.find_or_create_for_platform!(platform_project_id:, name: nil, environment: "live")
    find_or_create_by!(platform_project_id: platform_project_id) do |p|
      p.name = name
      p.environment = environment
    end
  end

  def api_key
    settings&.dig("api_key")
  end

  def ingest_key
    settings&.dig("ingest_key")
  end

  def origin_allowed?(origin)
    allowed = settings&.dig("allowed_origins")
    return true if allowed.blank?
    allowed.include?(origin)
  end

  private

  def generate_keys
    self.settings ||= {}
    self.settings["api_key"] ||= "sig_api_#{SecureRandom.hex(24)}"
    self.settings["ingest_key"] ||= "sig_ingest_#{SecureRandom.hex(24)}"
    self.settings["allowed_origins"] ||= []
  end
end
