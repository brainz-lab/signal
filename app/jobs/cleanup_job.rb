class CleanupJob < ApplicationJob
  queue_as :maintenance

  def perform
    # Clean up old resolved alerts (older than 90 days)
    Alert.resolved
      .where("resolved_at < ?", 90.days.ago)
      .delete_all

    # Clean up old alert history (older than 90 days)
    AlertHistory
      .where("timestamp < ?", 90.days.ago)
      .delete_all

    # Clean up old notifications (older than 30 days)
    Notification
      .where("created_at < ?", 30.days.ago)
      .delete_all

    # Clean up expired maintenance windows
    MaintenanceWindow
      .where("ends_at < ?", 30.days.ago)
      .where(recurring: false)
      .delete_all

    Rails.logger.info("CleanupJob completed at #{Time.current}")
  end
end
