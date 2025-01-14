class SchemesController < ApplicationController
  include Pagy::Backend
  include Modules::SearchFilter

  before_action :authenticate_user!
  before_action :find_resource, except: %i[index]
  before_action :authenticate_scope!
  before_action :redirect_if_scheme_confirmed, only: %i[primary_client_group confirm_secondary_client_group secondary_client_group support details]

  def index
    redirect_to schemes_organisation_path(current_user.organisation) unless current_user.support?
    all_schemes = Scheme.all.order("service_name ASC")

    @pagy, @schemes = pagy(filtered_collection(all_schemes, search_term))
    @searched = search_term.presence
    @total_count = all_schemes.size
  end

  def show
    @scheme = Scheme.find_by(id: params[:id])
    render_not_found and return unless @scheme
  end

  def new
    @scheme = Scheme.new
  end

  def create
    @scheme = Scheme.new(scheme_params)

    validation_errors scheme_params

    if @scheme.errors.empty? && @scheme.save
      if @scheme.arrangement_type_before_type_cast == "D"
        redirect_to scheme_primary_client_group_path(@scheme)
      else
        redirect_to scheme_support_services_provider_path(@scheme)
      end
    else
      @scheme.errors.add(:owning_organisation_id, message: @scheme.errors[:organisation])
      @scheme.errors.delete(:owning_organisation)
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    render_not_found and return unless @scheme
  end

  def update
    render_not_found and return unless @scheme

    check_answers = params[:scheme][:check_answers]
    page = params[:scheme][:page]
    scheme_previously_confirmed = @scheme.confirmed?

    validation_errors scheme_params
    if @scheme.errors.empty? && @scheme.update(scheme_params)
      if scheme_params[:confirmed] == "true"
        @scheme.locations.update!(confirmed: true)
        flash[:notice] = if scheme_previously_confirmed
                           "#{@scheme.service_name} has been updated."
                         else
                           "#{@scheme.service_name} has been created."
                         end
        redirect_to scheme_path(@scheme)
      elsif check_answers
        if confirm_secondary_page? page
          redirect_to scheme_secondary_client_group_path(@scheme, check_answers: "true")
        else
          @scheme.update!(secondary_client_group: nil) if @scheme.has_other_client_group == "No"
          redirect_to scheme_check_answers_path(@scheme)
        end
      else
        redirect_to next_page_path params[:scheme][:page]
      end
    else
      render current_template(page), status: :unprocessable_entity
    end
  end

  def primary_client_group
    render_not_found and return unless @scheme

    render "schemes/primary_client_group"
  end

  def confirm_secondary_client_group
    render_not_found and return unless @scheme

    render "schemes/confirm_secondary"
  end

  def secondary_client_group
    render_not_found and return unless @scheme

    render "schemes/secondary_client_group"
  end

  def support
    render_not_found and return unless @scheme

    render "schemes/support"
  end

  def details
    render_not_found and return unless @scheme

    render "schemes/details"
  end

  def check_answers
    render_not_found and return unless @scheme

    render "schemes/check_answers"
  end

  def edit_name
    render_not_found and return unless @scheme

    render "schemes/edit_name"
  end

  def support_services_provider
    render_not_found and return unless @scheme

    render "schemes/support_services_provider"
  end

private

  def validation_errors(scheme_params)
    scheme_params.each_key do |key|
      if scheme_params[key].to_s.empty?
        @scheme.errors.add(key.to_sym)
      end
    end

    if @scheme.arrangement_type_same? && arrangement_type_value(scheme_params[:arrangement_type]) != "D"
      @scheme.errors.delete(:managing_organisation_id)
    end
  end

  def confirm_secondary_page?(page)
    page == "confirm-secondary" && @scheme.has_other_client_group == "Yes"
  end

  def current_template(page)
    if page.include?("primary")
      "schemes/primary_client_group"
    elsif page.include?("support-services-provider")
      "schemes/support_services_provider"
    elsif page.include?("confirm")
      "schemes/confirm_secondary"
    elsif page.include?("secondary-client")
      "schemes/secondary_client_group"
    elsif page.include?("support")
      "schemes/support"
    elsif page.include?("details")
      "schemes/details"
    elsif page.include?("edit")
      "schemes/edit_name"
    elsif page.include?("check-answers")
      "schemes/check_answers"
    end
  end

  def next_page_path(page)
    case page
    when "support-services-provider"
      scheme_primary_client_group_path(@scheme)
    when "primary-client-group"
      scheme_confirm_secondary_client_group_path(@scheme)
    when "confirm-secondary"
      @scheme.has_other_client_group == "Yes" ? scheme_secondary_client_group_path(@scheme) : scheme_support_path(@scheme)
    when "secondary-client-group"
      scheme_support_path(@scheme)
    when "support"
      new_location_path
    when "details"
      if @scheme.arrangement_type_before_type_cast == "D"
        scheme_primary_client_group_path(@scheme)
      elsif @scheme.arrangement_type.present? && @scheme.arrangement_type_before_type_cast != "D"
        scheme_support_services_provider_path(@scheme)
      else
        scheme_details_path(@scheme)
      end
    when "edit-name"
      scheme_check_answers_path(@scheme)
    when "check-answers"
      schemes_path(scheme_id: @scheme.id)
    end
  end

  def scheme_params
    required_params = params.require(:scheme).permit(:service_name,
                                                     :sensitive,
                                                     :owning_organisation_id,
                                                     :managing_organisation_id,
                                                     :scheme_type,
                                                     :registered_under_care_act,
                                                     :id,
                                                     :has_other_client_group,
                                                     :primary_client_group,
                                                     :secondary_client_group,
                                                     :support_type,
                                                     :arrangement_type,
                                                     :intended_stay,
                                                     :confirmed)

    if arrangement_type_changed_to_different_org?(required_params)
      required_params[:managing_organisation_id] = nil
    end

    if arrangement_type_set_to_same_org?(required_params)
      required_params[:managing_organisation_id] = required_params[:owning_organisation_id] || @scheme.owning_organisation_id
    end

    required_params[:sensitive] = required_params[:sensitive].to_i if required_params[:sensitive]

    if current_user.data_coordinator?
      required_params[:owning_organisation_id] = current_user.organisation_id
    end
    required_params
  end

  def arrangement_type_set_to_same_org?(required_params)
    return unless @scheme

    arrangement_type_value(required_params[:arrangement_type]) == "D" || (required_params[:arrangement_type].blank? && @scheme.arrangement_type_same?)
  end

  def arrangement_type_changed_to_different_org?(required_params)
    return unless @scheme

    @scheme.arrangement_type_same? && arrangement_type_value(required_params[:arrangement_type]) != "D" && required_params[:managing_organisation_id].blank?
  end

  def arrangement_type_value(key)
    key.present? ? Scheme::ARRANGEMENT_TYPE[key.to_sym] : nil
  end

  def search_term
    params["search"]
  end

  def find_resource
    @scheme = Scheme.find_by(id: params[:id]) || Scheme.find_by(id: params[:scheme_id])
  end

  def authenticate_scope!
    head :unauthorized and return unless current_user.data_coordinator? || current_user.support?

    if %w[show locations primary_client_group confirm_secondary_client_group secondary_client_group support details check_answers edit_name].include?(action_name) && !((current_user.organisation == @scheme&.owning_organisation) || current_user.support?)
      render_not_found and return
    end
  end

  def redirect_if_scheme_confirmed
    redirect_to @scheme if @scheme.confirmed?
  end
end
