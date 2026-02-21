module Dashboard
  class SavedSearchesController < BaseController
    def create
      @saved_search = @project.saved_searches.new(saved_search_params)

      if @saved_search.save
        redirect_to dashboard_project_alerts_path(@project, @saved_search.query_params),
          notice: "Search '#{@saved_search.name}' saved"
      else
        redirect_to dashboard_project_alerts_path(@project),
          alert: @saved_search.errors.full_messages.join(", ")
      end
    end

    def destroy
      @saved_search = @project.saved_searches.find(params[:id])
      @saved_search.destroy
      redirect_to dashboard_project_alerts_path(@project), notice: "Search deleted"
    end

    private

    def saved_search_params
      params.require(:saved_search).permit(:name, query_params: {})
    end
  end
end
