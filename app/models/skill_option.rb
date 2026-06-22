# frozen_string_literal: true

# == Schema Information
#
# Table name: skill_options
#
#  id                   :bigint           not null, primary key
#  category             :string           default("technical"), not null
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
#  index_skill_options_on_category                       (category)
#  index_skill_options_on_normalized_value_and_category  (normalized_value,category) UNIQUE
#  index_skill_options_on_status                         (status)
#  index_skill_options_on_submitted_by_user_id           (submitted_by_user_id)
#  index_skill_options_on_value_trgm                     (value) USING gin
#
# Foreign Keys
#
#  fk_rails_...  (submitted_by_user_id => users.id)
#
class SkillOption < ApplicationRecord
  include Lookups::Optionable

  CATEGORIES = %w[technical soft tools].freeze

  validates :category, inclusion: { in: CATEGORIES }
end
