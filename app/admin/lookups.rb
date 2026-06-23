# frozen_string_literal: true

# Registers an ActiveAdmin screen for every resume-editor lookup table under a
# single "Lookups" menu, so admins can add / edit / delete options and review +
# approve the values end-users submit. One loop instead of eleven near-identical
# files.
LOOKUP_ADMIN_MODELS = [
  Country, City, JobTitle, Industry, Degree, FieldOfStudy,
  SkillOption, Technology, Language, LanguageProficiency, Interest
].freeze

LOOKUP_ADMIN_MODELS.each do |lookup_model|
  # `available_column_names` (from Lookups::Optionable) tolerates a missing database
  # connection, so this file can load during `assets:precompile` without a DB.
  has_category = lookup_model.available_column_names.include?('category')

  ActiveAdmin.register lookup_model do
    menu parent: 'Lookups', label: lookup_model.model_name.human.pluralize

    permit_params(*[:value, :status, :position, (:category if has_category)].compact)

    scope :all, default: true
    scope('Pending') { |s| s.where(status: 'pending') }
    scope('Approved') { |s| s.where(status: 'approved') }

    batch_action :approve do |ids|
      # rubocop:disable Rails/SkipsModelValidations
      lookup_model.where(id: ids).update_all(status: 'approved', updated_at: Time.current)
      # rubocop:enable Rails/SkipsModelValidations
      redirect_back_or_to(collection_path, notice: "#{ids.size} option(s) approved.")
    end

    index do
      selectable_column
      id_column
      column :value
      column :category if has_category
      column :status
      column :usage_count
      column :submitted_by_user
      column :updated_at
      actions
    end

    filter :value
    filter :status, as: :select, collection: Lookups::Optionable::STATUSES
    filter :category, as: :select, collection: SkillOption::CATEGORIES if has_category
    filter :updated_at

    form do |f|
      f.inputs do
        f.input :value
        f.input :category, as: :select, collection: SkillOption::CATEGORIES if has_category
        f.input :status, as: :select, collection: Lookups::Optionable::STATUSES,
                         hint: 'Approved options are shown to all users; pending ones await review.'
        f.input :position, hint: 'Higher numbers show first in the dropdown.'
      end
      f.actions
    end

    show do
      attributes_table do
        row :id
        row :value
        row :category if has_category
        row :status
        row :usage_count
        row :position
        row :submitted_by_user
        row :created_at
        row :updated_at
      end
    end
  end
end
