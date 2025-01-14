class Form::Setup::Pages::TenantCode < ::Form::Page
  def initialize(id, hsh, subsection)
    super
    @id = "tenant_code"
    @header = ""
    @description = ""
    @subsection = subsection
  end

  def questions
    @questions ||= [
      Form::Setup::Questions::TenantCode.new(nil, nil, self),
    ]
  end
end
