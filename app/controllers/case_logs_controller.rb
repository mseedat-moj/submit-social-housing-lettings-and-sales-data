class CaseLogsController < ApplicationController
  include Pagy::Backend
  include Modules::CaseLogsFilter
  include Modules::SearchFilter

  skip_before_action :verify_authenticity_token, if: :json_api_request?
  before_action :authenticate, if: :json_api_request?
  before_action :authenticate_user!, unless: :json_api_request?
  before_action :find_resource, except: %i[create index edit]

  def index
    set_session_filters

    all_logs = current_user.case_logs
    unpaginated_filtered_logs = filtered_case_logs(filtered_collection(all_logs, search_term))

    respond_to do |format|
      format.html do
        @pagy, @case_logs = pagy(unpaginated_filtered_logs)
        @searched = search_term.presence
        @total_count = all_logs.size
      end

      format.csv do
        send_data byte_order_mark + unpaginated_filtered_logs.to_csv(current_user), filename: "logs-#{Time.zone.now}.csv"
      end
    end
  end

  def create
    case_log = CaseLog.new(case_log_params)
    respond_to do |format|
      format.html do
        case_log.save!
        redirect_to case_log
      end
      format.json do
        if case_log.save
          render json: case_log, status: :created
        else
          render json: { errors: case_log.errors.messages }, status: :unprocessable_entity
        end
      end
    end
  end

  def update
    if @case_log
      if @case_log.update(api_case_log_params)
        render json: @case_log, status: :ok
      else
        render json: { errors: @case_log.errors.messages }, status: :unprocessable_entity
      end
    else
      render_not_found_json("Log", params[:id])
    end
  end

  def show
    respond_to do |format|
      # We don't have a dedicated non-editable show view
      format.html { edit }
      format.json do
        if @case_log
          render json: @case_log, status: :ok
        else
          render_not_found_json("Log", params[:id])
        end
      end
    end
  end

  def edit
    @case_log = current_user.case_logs.find_by(id: params[:id])
    if @case_log
      render :edit, locals: { current_user: }
    else
      render_not_found
    end
  end

  def destroy
    if @case_log
      if @case_log.delete
        head :no_content
      else
        render json: { errors: @case_log.errors.messages }, status: :unprocessable_entity
      end
    else
      render_not_found_json("Log", params[:id])
    end
  end

private

  API_ACTIONS = %w[create show update destroy].freeze

  def search_term
    params["search"]
  end

  def json_api_request?
    API_ACTIONS.include?(request["action"]) && request.format.json?
  end

  def authenticate
    http_basic_authenticate_or_request_with name: ENV["API_USER"], password: ENV["API_KEY"]
  end

  def case_log_params
    if current_user && !current_user.support?
      org_params.merge(api_case_log_params)
    else
      api_case_log_params
    end
  end

  def org_params
    {
      "owning_organisation_id" => current_user.organisation.id,
      "managing_organisation_id" => current_user.organisation.id,
      "created_by_id" => current_user.id,
    }
  end

  def api_case_log_params
    return {} unless params[:case_log]

    permitted = params.require(:case_log).permit(CaseLog.editable_fields)
    owning_id = permitted["owning_organisation_id"]
    permitted["owning_organisation"] = Organisation.find(owning_id) if owning_id
    permitted
  end

  def find_resource
    @case_log = CaseLog.find_by(id: params[:id])
  end
end
