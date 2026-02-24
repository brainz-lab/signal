class NotificationRateLimiter
  # Per-channel: max 60 notifications per 5 minutes
  CHANNEL_LIMIT = 60
  CHANNEL_WINDOW = 5.minutes

  # Per-rule: max 10 fires per hour
  RULE_LIMIT = 10
  RULE_WINDOW = 1.hour

  # Per-project: max 500 notifications per hour
  PROJECT_LIMIT = 500
  PROJECT_WINDOW = 1.hour

  def initialize(project:, channel: nil, rule: nil)
    @project = project
    @channel = channel
    @rule = rule
  end

  def allowed?
    reason = check_limits
    reason.nil?
  end

  def check_limits
    if @channel && over_channel_limit?
      return "Channel rate limit exceeded (#{CHANNEL_LIMIT}/#{CHANNEL_WINDOW.inspect})"
    end

    if @rule && over_rule_limit?
      return "Rule rate limit exceeded (#{RULE_LIMIT}/#{RULE_WINDOW.inspect})"
    end

    if over_project_limit?
      return "Project rate limit exceeded (#{PROJECT_LIMIT}/#{PROJECT_WINDOW.inspect})"
    end

    nil
  end

  private

  def over_channel_limit?
    count = increment_counter("signal:rate:channel:#{@channel.id}", CHANNEL_WINDOW)
    count > CHANNEL_LIMIT
  end

  def over_rule_limit?
    count = increment_counter("signal:rate:rule:#{@rule.id}", RULE_WINDOW)
    count > RULE_LIMIT
  end

  def over_project_limit?
    count = increment_counter("signal:rate:project:#{@project.id}", PROJECT_WINDOW)
    count > PROJECT_LIMIT
  end

  def increment_counter(key, window)
    Rails.cache.increment(key, 1, expires_in: window) || begin
      Rails.cache.write(key, 1, expires_in: window)
      1
    end
  end
end
