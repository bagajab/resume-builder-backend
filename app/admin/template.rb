# frozen_string_literal: true

ActiveAdmin.register Template do
  # `name` and `description` are display copy and can be renamed freely from here
  # — that's the whole point: renaming a template is a data change, never a code
  # change. `slug` is the immutable identifier the apps key off of (component
  # resolution, PDF pipelines, seeds), so it is editable only when creating a
  # new template and locked thereafter.
  permit_params do
    permitted = %i[name description]
    permitted << :slug if params[:action] == 'create' || params[:id].blank?
    permitted
  end

  form do |f|
    f.inputs 'Template' do
      if f.object.new_record?
        f.input :slug, hint: 'Stable code identifier (e.g. "spotlight"). Cannot be changed later.'
      else
        f.input :slug, input_html: { disabled: true },
                       hint: 'Locked — the apps reference templates by slug.'
      end
      f.input :name, hint: 'Display name shown to users. Safe to rename anytime.'
      f.input :description, hint: 'Short tagline shown on marketing cards.'
    end

    actions
  end

  index do
    selectable_column
    id_column
    column :slug
    column :name
    column :description
    column :resumes_count do |template|
      template.resumes.count
    end
    column :updated_at

    actions
  end

  filter :slug
  filter :name
  filter :created_at
  filter :updated_at

  show do
    attributes_table do
      row :id
      row :slug
      row :name
      row :description
      row :created_at
      row :updated_at
    end
  end
end
