# frozen_string_literal: true

# == Schema Information
#
# Table name: fields_of_study
#
#  id                   :bigint           not null, primary key
#  normalized_value     :string           not null
#  position             :integer          default(0), not null
#  status               :string           default("approved"), not null
#  usage_count          :integer          default(0), not null
#  value                :string           not null
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#  submitted_by_user_id :bigint
#
# Indexes
#
#  index_fields_of_study_on_normalized_value      (normalized_value) UNIQUE
#  index_fields_of_study_on_status                (status)
#  index_fields_of_study_on_submitted_by_user_id  (submitted_by_user_id)
#  index_fields_of_study_on_value_trgm            (value) USING gin
#
# Foreign Keys
#
#  fk_rails_...  (submitted_by_user_id => users.id)
#
class FieldOfStudy < ApplicationRecord
  # Rails would pluralize this to `field_of_studies`; the table is `fields_of_study`.
  self.table_name = 'fields_of_study'

  include Lookups::Optionable
end
