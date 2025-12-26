module Dashboard
  class ChannelsController < BaseController
    def index
      @channels = @project.notification_channels.order(created_at: :desc)

      # Filter by type
      if params[:channel_type].present?
        @channels = @channels.where(channel_type: params[:channel_type])
      end

      @channels = @channels.limit(100)

      # Stats
      @total_count = @project.notification_channels.count
      @enabled_count = @project.notification_channels.where(enabled: true).count
      @verified_count = @project.notification_channels.where(verified: true).count
    end

    def show
      @channel = @project.notification_channels.find(params[:id])
      @recent_notifications = @channel.notifications.order(created_at: :desc).limit(10)
    end

    def new
      @channel = @project.notification_channels.new
    end

    def create
      @channel = @project.notification_channels.new(channel_params)
      if @channel.save
        redirect_to dashboard_project_channel_path(@project, @channel), notice: 'Channel created successfully'
      else
        render :new
      end
    end

    def edit
      @channel = @project.notification_channels.find(params[:id])
    end

    def update
      @channel = @project.notification_channels.find(params[:id])
      if @channel.update(channel_params)
        redirect_to dashboard_project_channel_path(@project, @channel), notice: 'Channel updated successfully'
      else
        render :edit
      end
    end

    def destroy
      @channel = @project.notification_channels.find(params[:id])
      @channel.destroy
      redirect_to dashboard_project_channels_path(@project), notice: 'Channel deleted'
    end

    def test
      @channel = @project.notification_channels.find(params[:id])
      result = @channel.test!
      if result[:success]
        redirect_to dashboard_project_channel_path(@project, @channel), notice: 'Test notification sent successfully'
      else
        redirect_to dashboard_project_channel_path(@project, @channel), alert: "Test failed: #{result[:error]}"
      end
    end

    private

    def channel_params
      params.require(:notification_channel).permit(:name, :channel_type, :enabled, config: {})
    end
  end
end
