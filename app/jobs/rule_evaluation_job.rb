class RuleEvaluationJob < ApplicationJob
  queue_as :alerts

  def perform(rule_id = nil)
    if rule_id
      # Evaluate single rule
      rule = AlertRule.find(rule_id)
      rule.evaluate! if rule.enabled? && !rule.muted?
    else
      # Evaluate all active rules
      AlertRule.active.find_each do |rule|
        rule.evaluate!
      rescue => e
        Rails.logger.error("Error evaluating rule #{rule.id}: #{e.message}")
      end
    end
  end
end
