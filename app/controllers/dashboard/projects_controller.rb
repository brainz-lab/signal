module Dashboard
  class ProjectsController < BaseController
    skip_before_action :set_project, only: [ :index, :new, :create ], raise: false
    skip_before_action :authenticate_via_sso!, only: [ :index, :new, :create ], raise: false, if: -> { Rails.env.development? }
    before_action :redirect_to_platform_in_production, only: [ :new, :create ]

    def index
      if Rails.env.development?
        # In dev, show all projects (including archived for debugging)
        @projects = Project.active.order(created_at: :desc)
      elsif session[:platform_project_id]
        # SSO flow - find or create project from session
        project = Project.find_or_create_for_platform!(
          platform_project_id: session[:platform_project_id],
          name: session[:project_slug] || "Project"
        )
        redirect_to dashboard_project_overview_path(project)
      elsif @api_key_info && @api_key_info[:project_id]
        # API key flow
        project = Project.find_or_create_for_platform!(
          platform_project_id: @api_key_info[:project_id],
          name: @api_key_info[:project_name],
          environment: @api_key_info[:environment] || "live"
        )
        @projects = [ project ]
      else
        redirect_to new_dashboard_project_path
      end
    end

    def new
      @project = Project.new
    end

    def create
      if Rails.env.development?
        # In dev, create project directly
        @project = Project.new(
          name: params[:project]&.[](:name) || params[:name],
          environment: params[:project]&.[](:environment) || "development",
          platform_project_id: SecureRandom.uuid
        )

        if @project.name.blank?
          flash.now[:alert] = "Please enter a project name"
          return render :new, status: :unprocessable_entity
        end

        if @project.save
          session[:api_key] = "dev_#{@project.id}"
          redirect_to dashboard_project_overview_path(@project), notice: "Created #{@project.name}"
        else
          flash.now[:alert] = @project.errors.full_messages.join(", ")
          render :new, status: :unprocessable_entity
        end
      else
        # In production, require API key from Platform
        api_key = params[:api_key]&.strip

        if api_key.blank?
          flash.now[:alert] = "Please enter an API key"
          @project = Project.new
          return render :new, status: :unprocessable_entity
        end

        key_info = PlatformClient.validate_key(api_key)

        unless key_info[:valid]
          flash.now[:alert] = "Invalid API key. Please check and try again."
          @project = Project.new
          return render :new, status: :unprocessable_entity
        end

        project = Project.find_or_create_for_platform!(
          platform_project_id: key_info[:project_id],
          name: key_info[:project_name],
          environment: key_info[:environment] || "live"
        )

        session[:api_key] = api_key
        redirect_to dashboard_project_overview_path(project), notice: "Connected to #{project.name}"
      end
    end

    def show
      redirect_to dashboard_project_overview_path(@project)
    end

    def edit
    end

    def setup
    end

    def update
      if @project.update(project_params)
        redirect_to edit_dashboard_project_path(@project), notice: "Project updated successfully"
      else
        render :edit
      end
    end

    def destroy
      @project.destroy
      session.delete(:api_key)
      redirect_to dashboard_projects_path, notice: "Project deleted"
    end

    private

    def project_params
      params.require(:project).permit(:name, :environment, :platform_project_id, settings: {})
    end

    def redirect_to_platform_in_production
      return unless Rails.env.production?

      platform_url = ENV.fetch("BRAINZLAB_PLATFORM_EXTERNAL_URL", "https://platform.brainzlab.ai")
      redirect_to platform_url, allow_other_host: true
    end
  end
end
