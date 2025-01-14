class Form::Setup::Pages::RentType < ::Form::Page
  def initialize(_id, hsh, subsection)
    super("rent_type", hsh, subsection)
    @header = ""
    @description = ""
    @derived = true
  end

  def questions
    @questions ||= [
      Form::Setup::Questions::RentType.new(nil, nil, self),
      Form::Setup::Questions::IrproductOther.new(nil, nil, self),
    ]
  end
end
