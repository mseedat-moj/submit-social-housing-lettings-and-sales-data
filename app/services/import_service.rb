class ImportService
  def initialize(storage_service, logger = Rails.logger)
    @storage_service = storage_service
    @logger = logger
  end

  def update_organisations(folder)
    filenames = @storage_service.list_files(folder)
    filenames.each do |filename|
      file_io = @storage_service.get_file_io(filename)
      create_organisation(file_io)
    end
  end

private

  def create_organisation(file_io)
    doc = Nokogiri::XML(file_io)
    name = field_value(doc, "name")
    old_visible_id = field_value(doc, "visible-id")
    begin
      Organisation.create!(
        name: name,
        providertype: field_value(doc, "institution-type"),
        phone: field_value(doc, "telephone-number"),
        holds_own_stock: to_boolean(field_value(doc, "holds-stock")),
        active: to_boolean(field_value(doc, "active")),
        old_association_type: field_value(doc, "old-association-type"),
        software_supplier_id: field_value(doc, "software-supplier-id"),
        housing_management_system: field_value(doc, "housing-management-system"),
        choice_based_lettings: to_boolean(field_value(doc, "choice-based-lettings")),
        common_housing_register: to_boolean(field_value(doc, "common-housing-register")),
        choice_allocation_policy: to_boolean(field_value(doc, "choice-allocation-policy")),
        cbl_proportion_percentage: field_value(doc, "cbl-proportion-percentage"),
        enter_affordable_logs: to_boolean(field_value(doc, "enter-affordable-logs")),
        owns_affordable_logs: to_boolean(field_value(doc, "owns-affordable-rent")),
        housing_registration_no: field_value(doc, "housing-registration-no"),
        general_needs_units: field_value(doc, "general-needs-units"),
        supported_housing_units: field_value(doc, "supported-housing-units"),
        unspecified_units: field_value(doc, "unspecified-units"),
        old_org_id: field_value(doc, "id"),
        old_visible_id: old_visible_id,
      )
    rescue ActiveRecord::RecordNotUnique
      @logger.warn("Organisation #{name} is already present with old visible ID #{old_visible_id}, skipping.")
    end
  end

  def field_value(doc, field)
    doc.at_xpath("//institution:#{field}")&.text
  end

  def to_boolean(input_string)
    input_string == "true"
  end
end
