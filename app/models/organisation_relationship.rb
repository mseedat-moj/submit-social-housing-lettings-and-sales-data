class OrganisationRelationship < ApplicationRecord
  belongs_to :child_organisation, class_name: "Organisation"
  belongs_to :parent_organisation, class_name: "Organisation"
end
