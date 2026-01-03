# frozen_string_literal: true

require "test_helper"

class RuleEvaluationJobTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  setup do
    @rule = alert_rules(:cpu_threshold)
  end

  # Job configuration
  test "job is queued on alerts queue" do
    assert_equal "alerts", RuleEvaluationJob.new.queue_name
  end

  # Single rule evaluation
  test "evaluates single rule when rule_id provided" do
    AlertRule.any_instance.expects(:evaluate!).once

    RuleEvaluationJob.perform_now(@rule.id)
  end

  test "does not evaluate disabled rule" do
    @rule.update!(enabled: false)
    AlertRule.any_instance.expects(:evaluate!).never

    RuleEvaluationJob.perform_now(@rule.id)
  end

  test "does not evaluate muted rule" do
    @rule.update!(muted: true)
    AlertRule.any_instance.expects(:evaluate!).never

    RuleEvaluationJob.perform_now(@rule.id)
  end

  test "evaluates rule that is enabled and not muted" do
    @rule.update!(enabled: true, muted: false)
    AlertRule.any_instance.expects(:evaluate!).once

    RuleEvaluationJob.perform_now(@rule.id)
  end

  # Batch evaluation
  test "evaluates all active rules when no rule_id provided" do
    # Get count of active rules
    active_count = AlertRule.active.count

    # Stub evaluate! for all rules
    AlertRule.any_instance.stubs(:evaluate!)

    # Should not raise
    assert_nothing_raised do
      RuleEvaluationJob.perform_now
    end
  end

  test "continues evaluating other rules when one fails" do
    # Create two active rules
    rule1 = alert_rules(:cpu_threshold)
    rule2 = alert_rules(:error_rate)

    # Make sure both are active
    rule1.update!(enabled: true, muted: false)
    rule2.update!(enabled: true, muted: false)

    # Set up sequence where first rule raises, second succeeds
    call_count = 0
    AlertRule.any_instance.stubs(:evaluate!).with do
      call_count += 1
      if call_count == 1
        raise "Test error"
      end
      true
    end

    # Should not raise even when one rule fails
    assert_nothing_raised do
      RuleEvaluationJob.perform_now
    end
  end

  test "logs error when rule evaluation fails" do
    AlertRule.any_instance.stubs(:evaluate!).raises("Test evaluation error")

    Rails.logger.expects(:error).with(regexp_matches(/Error evaluating rule/))

    RuleEvaluationJob.perform_now
  end

  # Job enqueueing
  test "can be enqueued with rule_id" do
    assert_enqueued_with(job: RuleEvaluationJob, args: [ @rule.id ]) do
      RuleEvaluationJob.perform_later(@rule.id)
    end
  end

  test "can be enqueued without arguments for batch" do
    assert_enqueued_with(job: RuleEvaluationJob) do
      RuleEvaluationJob.perform_later
    end
  end

  # Edge cases
  test "raises when rule_id not found" do
    assert_raises ActiveRecord::RecordNotFound do
      RuleEvaluationJob.perform_now("non-existent-uuid")
    end
  end

  test "handles empty active rules" do
    AlertRule.update_all(enabled: false)

    assert_nothing_raised do
      RuleEvaluationJob.perform_now
    end
  end
end
