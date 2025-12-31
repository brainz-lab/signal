class AlertRule < ApplicationRecord
  belongs_to :escalation_policy, optional: true
  has_many :alerts, dependent: :destroy
  has_many :alert_histories, dependent: :destroy

  validates :name, presence: true
  validates :slug, presence: true, uniqueness: { scope: :project_id }
  validates :source, presence: true, inclusion: { in: %w[flux pulse reflex recall] }
  validates :rule_type, presence: true, inclusion: { in: %w[threshold anomaly absence composite] }
  validates :severity, inclusion: { in: %w[info warning critical] }
  validates :project_id, presence: true

  before_validation :generate_slug, on: :create

  scope :enabled, -> { where(enabled: true) }
  scope :active, -> { enabled.where(muted: false).where("muted_until IS NULL OR muted_until < ?", Time.current) }
  scope :by_source, ->(source) { where(source: source) }
  scope :firing, -> { joins(:alerts).where(alerts: { state: "firing" }).distinct }
  scope :for_project, ->(project_id) { where(project_id: project_id) }

  OPERATORS = {
    "gt" => ">",
    "gte" => ">=",
    "lt" => "<",
    "lte" => "<=",
    "eq" => "==",
    "neq" => "!="
  }.freeze

  def evaluate!
    evaluator = RuleEvaluator.new(self)
    result = evaluator.evaluate

    update!(
      last_evaluated_at: Time.current,
      last_state: result[:state]
    )

    # Record history
    AlertHistory.create!(
      project_id: project_id,
      alert_rule: self,
      timestamp: Time.current,
      state: result[:state],
      value: result[:value],
      labels: result[:labels] || {},
      fingerprint: result[:fingerprint]
    )

    # Handle state transitions
    AlertManager.new(self).process(result)

    result
  end

  def mute!(until_time: nil, reason: nil)
    update!(
      muted: true,
      muted_until: until_time,
      muted_reason: reason
    )
  end

  def unmute!
    update!(muted: false, muted_until: nil, muted_reason: nil)
  end

  def muted?
    return false unless muted
    return true if muted_until.nil?
    muted_until > Time.current
  end

  def notification_channels
    NotificationChannel.where(id: notify_channels)
  end

  def condition_description
    case rule_type
    when "threshold"
      "#{aggregation}(#{source_name}) #{OPERATORS[operator]} #{threshold} over #{window}"
    when "anomaly"
      "Anomaly detected in #{source_name} (sensitivity: #{sensitivity})"
    when "absence"
      "No data for #{source_name} in #{expected_interval}"
    when "composite"
      "Composite rule: #{composite_rules.count} sub-rules"
    end
  end

  private

  def generate_slug
    self.slug ||= name&.parameterize
  end
end
