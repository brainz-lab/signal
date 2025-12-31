module Api
  module V1
    class ChannelsController < BaseController
      before_action :set_channel, only: [ :show, :update, :destroy, :test ]

      def index
        channels = NotificationChannel.for_project(@project_id).order(:name)
        render json: {
          channels: channels.map { |c| serialize_channel(c) }
        }
      end

      def show
        render json: serialize_channel(@channel, full: true)
      end

      def create
        channel = NotificationChannel.new(channel_params)
        channel.project_id = @project_id

        if channel.save
          render json: serialize_channel(channel), status: :created
        else
          render json: { errors: channel.errors.full_messages }, status: :unprocessable_entity
        end
      end

      def update
        if @channel.update(channel_params)
          render json: serialize_channel(@channel)
        else
          render json: { errors: @channel.errors.full_messages }, status: :unprocessable_entity
        end
      end

      def destroy
        @channel.destroy!
        head :no_content
      end

      def test
        result = @channel.test!
        render json: {
          success: result[:success],
          error: result[:error],
          channel: serialize_channel(@channel)
        }
      end

      private

      def set_channel
        @channel = NotificationChannel.for_project(@project_id).find(params[:id])
      rescue ActiveRecord::RecordNotFound
        render_not_found
      end

      def channel_params
        params.require(:channel).permit(
          :name, :channel_type, :enabled,
          config: {}
        )
      end

      def serialize_channel(channel, full: false)
        data = {
          id: channel.id,
          name: channel.name,
          slug: channel.slug,
          channel_type: channel.channel_type,
          enabled: channel.enabled,
          verified: channel.verified,
          last_used_at: channel.last_used_at,
          success_count: channel.success_count,
          failure_count: channel.failure_count
        }

        if full
          # Mask sensitive config values
          data[:config] = mask_config(channel.config)
        end

        data
      end

      def mask_config(config)
        return {} unless config.is_a?(Hash)
        config.transform_values do |v|
          v.is_a?(String) && v.length > 8 ? "#{v[0..3]}...#{v[-4..]}" : v
        end
      end
    end
  end
end
