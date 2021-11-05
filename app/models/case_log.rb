class CaseLogValidator < ActiveModel::Validator
  # Validations methods need to be called 'validate_<page_name>' to run on model save
  # or 'validate_' to run on submit as well
  include HouseholdValidations
  include PropertyValidations
  include FinancialValidations
  include TenancyValidations

  def validate(record)
    # If we've come from the form UI we only want to validate the specific fields
    # that have just been submitted. If we're submitting a log via API or Bulk Upload
    # we want to validate all data fields.
    page_to_validate = options[:page]
    if page_to_validate
      public_send("validate_#{page_to_validate}", record) if respond_to?("validate_#{page_to_validate}")
    else
      validation_methods = public_methods.select { |method| method.starts_with?("validate_") }
      validation_methods.each { |meth| public_send(meth, record) }
    end
  end

private

  def validate_other_field(record, main_field, other_field)
    main_field_label = main_field.humanize(capitalize: false)
    other_field_label = other_field.humanize(capitalize: false)
    if record[main_field] == "Other" && record[other_field].blank?
      record.errors.add other_field.to_sym, "If #{main_field_label} is other then #{other_field_label} must be provided"
    end

    if record[main_field] != "Other" && record[other_field].present?
      record.errors.add other_field.to_sym, "#{other_field_label} must not be provided if #{main_field_label} was not other"
    end
  end
end

class CaseLog < ApplicationRecord
  include Discard::Model
  include SoftValidations
  default_scope -> { kept }
  scope :not_completed, -> { where.not(status: "completed") }

  validates_with CaseLogValidator, ({ page: @page } || {})
  before_save :update_status!

  attr_accessor :page

  enum status: { "not_started" => 0, "in_progress" => 1, "completed" => 2 }

  AUTOGENERATED_FIELDS = %w[id status created_at updated_at discarded_at].freeze

  def self.editable_fields
    attribute_names - AUTOGENERATED_FIELDS
  end

  def completed?
    status == "completed"
  end

  def not_started?
    status == "not_started"
  end

  def in_progress?
    status == "in_progress"
  end

  def weekly_net_income
    case net_income_frequency
    when "Weekly"
      net_income
    when "Monthly"
      ((net_income * 12) / 52.0).round(0)
    when "Yearly"
      (net_income / 12.0).round(0)
    end
  end

  def applicable_income_range
    return unless person_1_economic_status

    IncomeRange::ALLOWED[person_1_economic_status.to_sym]
  end

private

  def update_status!
    self.status = if all_fields_completed? && errors.empty?
                    "completed"
                  elsif all_fields_nil?
                    "not_started"
                  else
                    "in_progress"
                  end
  end

  def all_fields_completed?
    mandatory_fields.none? { |_key, val| val.nil? }
  end

  def all_fields_nil?
    mandatory_fields.all? { |_key, val| val.nil? }
  end

  def mandatory_fields
    required = attributes.except(*AUTOGENERATED_FIELDS)

    dynamically_not_required = []

    if reason_for_leaving_last_settled_home != "Other"
      dynamically_not_required << "other_reason_for_leaving_last_settled_home"
    end

    if net_income.to_i.zero?
      dynamically_not_required << "net_income_frequency"
    end

    if tenancy_type == "Fixed term – Secure"
      dynamically_not_required << "fixed_term_tenancy"
    end

    unless net_income_in_soft_max_range? || net_income_in_soft_min_range?
      dynamically_not_required << "override_net_income_validation"
    end

    unless tenancy_type == "Other"
      dynamically_not_required << "other_tenancy_type"
    end

    unless net_income_known == "Yes"
      dynamically_not_required << "net_income"
      dynamically_not_required << "net_income_frequency"
    end

    start_range = (household_number_of_other_members || 0) + 2
    (start_range..8).each do |n|
      dynamically_not_required << "person_#{n}_age"
      dynamically_not_required << "person_#{n}_gender"
      dynamically_not_required << "person_#{n}_relationship"
      dynamically_not_required << "person_#{n}_economic_status"
    end

    required.delete_if { |key, _value| dynamically_not_required.include?(key) }
  end
end
