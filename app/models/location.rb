class Location < ApplicationRecord
  validate :validate_postcode
  validates :units, :type_of_unit, :mobility_type, presence: true
  belongs_to :scheme

  has_paper_trail

  before_save :lookup_postcode!, if: :postcode_changed?

  auto_strip_attributes :name

  attr_accessor :add_another_location

  scope :search_by_postcode, ->(postcode) { where("REPLACE(postcode, ' ', '') ILIKE ?", "%#{postcode.delete(' ')}%") }
  scope :search_by_name, ->(name) { where("name ILIKE ?", "%#{name}%") }
  scope :search_by, ->(param) { search_by_name(param).or(search_by_postcode(param)) }
  scope :started, -> { where("startdate <= ?", Time.zone.today).or(where(startdate: nil)) }
  scope :active, -> { where(confirmed: true).and(started) }

  MOBILITY_TYPE = {
    "Wheelchair-user standard": "W",
    "Fitted with equipment and adaptations": "A",
    "Property designed to accessible general standard": "M",
    "None": "N",
    "Missing": "X",
  }.freeze

  enum mobility_type: MOBILITY_TYPE

  TYPE_OF_UNIT = {
    "Bungalow": 6,
    "Self-contained flat or bedsit": 1,
    "Self-contained flat or bedsit with common facilities": 2,
    "Self-contained house": 7,
    "Shared flat": 3,
    "Shared house or hostel": 4,
  }.freeze

  enum type_of_unit: TYPE_OF_UNIT

  def display_attributes
    [
      { name: "Location code ", value: location_code, suffix: false },
      { name: "Postcode", value: postcode, suffix: county },
      { name: "Type of unit", value: type_of_unit, suffix: false },
    ]
  end

  def postcode=(postcode)
    if postcode
      super UKPostcode.parse(postcode).to_s
    else
      super nil
    end
  end

private

  PIO = PostcodeService.new

  def validate_postcode
    if postcode.nil? || !postcode&.match(POSTCODE_REGEXP)
      error_message = I18n.t("validations.postcode")
      errors.add :postcode, error_message
    end
  end

  def lookup_postcode!
    result = PIO.lookup(postcode)
    if result
      self.location_code = result[:location_code]
      self.location_admin_district = result[:location_admin_district]
    end
  end
end
