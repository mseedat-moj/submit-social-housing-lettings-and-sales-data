class Form::Subsections::Setup < ::Form::Subsection
  def initialize(id, hsh, section)
    super
    @id = "setup"
    @label = "Set up this lettings log"
    @section = section
  end

  def pages
    @pages ||= [
      Form::Setup::Pages::Organisation.new(nil, nil, self),
      Form::Setup::Pages::CreatedBy.new(nil, nil, self),
      Form::Setup::Pages::NeedsType.new(nil, nil, self),
      Form::Setup::Pages::Scheme.new(nil, nil, self),
      Form::Setup::Pages::Location.new(nil, nil, self),
      Form::Setup::Pages::Renewal.new(nil, nil, self),
      Form::Setup::Pages::TenancyStartDate.new(nil, nil, self),
      Form::Setup::Pages::RentType.new(nil, nil, self),
      Form::Setup::Pages::TenantCode.new(nil, nil, self),
      Form::Setup::Pages::PropertyReference.new(nil, nil, self),
    ]
  end

  def applicable_questions(case_log)
    questions.select { |q| support_only_questions.include?(q.id) } + super
  end

  def enabled?(_case_log)
    true
  end

private

  def support_only_questions
    %w[owning_organisation_id created_by_id].freeze
  end
end
