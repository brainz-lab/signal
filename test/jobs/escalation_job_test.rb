# frozen_string_literal: true

require "test_helper"

class EscalationJobTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  setup do
    @policy = escalation_policies(:critical_policy)
    @rule = alert_rules(:cpu_threshold)
    @rule.update!(escalation_policy: @policy)

    @alert = alerts(:firing_alert)
    @alert.update!(alert_rule: @rule)
  end

  # Job configuration
  test "job is queued on alerts queue" do
    assert_equal "alerts", EscalationJob.new.queue_name
  end

  # Basic execution
  test "sends notifications for current step" do
    @policy.update!(steps: [
      { "channels" => [ notification_channels(:slack_channel).id ], "delay_minutes" => 0 }
    ])

    assert_enqueued_with(job: NotificationJob) do
      EscalationJob.perform_now(alert_id: @alert.id, step_index: 0)
    end
  end

  test "sends to multiple channels in step" do
    @policy.update!(steps: [
      {
        "channels" => [
          notification_channels(:slack_channel).id,
          notification_channels(:pagerduty_channel).id
        ],
        "delay_minutes" => 0
      }
    ])

    assert_enqueued_jobs 2, only: NotificationJob do
      EscalationJob.perform_now(alert_id: @alert.id, step_index: 0)
    end
  end

  # Skip conditions
  test "does not send when alert is not firing" do
    @alert.update!(state: "resolved")

    assert_no_enqueued_jobs only: NotificationJob do
      EscalationJob.perform_now(alert_id: @alert.id, step_index: 0)
    end
  end

  test "does not send when alert is acknowledged" do
    @alert.update!(acknowledged: true)

    assert_no_enqueued_jobs only: NotificationJob do
      EscalationJob.perform_now(alert_id: @alert.id, step_index: 0)
    end
  end

  test "does not send when rule has no escalation policy" do
    @rule.update!(escalation_policy: nil)
    @alert.reload

    assert_no_enqueued_jobs only: NotificationJob do
      EscalationJob.perform_now(alert_id: @alert.id, step_index: 0)
    end
  end

  test "does not send when step index is out of bounds" do
    @policy.update!(steps: [
      { "channels" => [ notification_channels(:slack_channel).id ], "delay_minutes" => 0 }
    ])

    assert_no_enqueued_jobs only: NotificationJob do
      EscalationJob.perform_now(alert_id: @alert.id, step_index: 5)
    end
  end

  # Next step scheduling
  test "schedules next step when exists" do
    @policy.update!(steps: [
      { "channels" => [ notification_channels(:slack_channel).id ], "delay_minutes" => 0 },
      { "channels" => [ notification_channels(:pagerduty_channel).id ], "delay_minutes" => 15 }
    ])

    assert_enqueued_with(job: EscalationJob) do
      EscalationJob.perform_now(alert_id: @alert.id, step_index: 0)
    end
  end

  test "does not schedule next step when at last step without repeat" do
    @policy.update!(
      steps: [
        { "channels" => [ notification_channels(:slack_channel).id ], "delay_minutes" => 0 }
      ],
      repeat: false
    )

    # Only NotificationJob should be enqueued, not another EscalationJob
    perform_enqueued_jobs do
      EscalationJob.perform_now(alert_id: @alert.id, step_index: 0)
    end
  end

  # Repeat behavior
  test "schedules repeat from beginning when repeat enabled" do
    @policy.update!(
      steps: [
        { "channels" => [ notification_channels(:slack_channel).id ], "delay_minutes" => 0 }
      ],
      repeat: true,
      repeat_after_minutes: 30
    )

    # Should enqueue with step_index: 0
    assert_enqueued_with(job: EscalationJob, args: [ { alert_id: @alert.id, step_index: 0 } ]) do
      EscalationJob.perform_now(alert_id: @alert.id, step_index: 0)
    end
  end

  test "does not repeat when repeat_after_minutes is nil" do
    @policy.update!(
      steps: [
        { "channels" => [ notification_channels(:slack_channel).id ], "delay_minutes" => 0 }
      ],
      repeat: true,
      repeat_after_minutes: nil
    )

    # Clear any pre-existing jobs
    clear_enqueued_jobs

    EscalationJob.perform_now(alert_id: @alert.id, step_index: 0)

    # Should only have NotificationJob, not EscalationJob for repeat
    escalation_jobs = enqueued_jobs.select { |j| j["job_class"] == "EscalationJob" }
    assert_equal 0, escalation_jobs.size
  end

  # Edge cases
  test "raises when alert not found" do
    assert_raises ActiveRecord::RecordNotFound do
      EscalationJob.perform_now(alert_id: "non-existent-uuid", step_index: 0)
    end
  end

  test "handles empty channels array in step" do
    @policy.update!(steps: [
      { "channels" => [], "delay_minutes" => 0 }
    ])

    assert_no_enqueued_jobs only: NotificationJob do
      EscalationJob.perform_now(alert_id: @alert.id, step_index: 0)
    end
  end

  # Job enqueueing
  test "can be enqueued with delay" do
    assert_enqueued_with(job: EscalationJob) do
      EscalationJob.set(wait: 15.minutes).perform_later(
        alert_id: @alert.id,
        step_index: 1
      )
    end
  end
end
