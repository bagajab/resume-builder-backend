# frozen_string_literal: true

class CreateResumeBuilderTables < ActiveRecord::Migration[8.1]
  def change
    create_table :resumes do |t|
      t.references :user, null: false, foreign_key: true
      t.string :title, null: false, default: 'Untitled Resume'
      t.integer :current_step, null: false, default: 1
      t.string :status, null: false, default: 'draft'
      t.integer :version, null: false, default: 1
      t.references :source_resume, foreign_key: { to_table: :resumes }

      t.timestamps
    end

    create_table :resume_profiles do |t|
      t.references :resume, null: false, foreign_key: true, index: { unique: true }
      t.string :full_name
      t.string :phone
      t.string :location_city
      t.string :location_country
      t.string :linkedin_url
      t.string :github_url
      t.string :portfolio_url
      t.string :job_title
      t.integer :years_of_experience
      t.string :industry
      t.text :career_summary
      t.jsonb :languages, null: false, default: []
      t.jsonb :awards, null: false, default: []
      t.jsonb :volunteer_experiences, null: false, default: []
      t.jsonb :references, null: false, default: []
      t.jsonb :interests, null: false, default: []
      t.jsonb :job_preferences, null: false, default: {}

      t.timestamps
    end

    create_table :experiences do |t|
      t.references :resume, null: false, foreign_key: true
      t.string :job_title, null: false
      t.string :company, null: false
      t.string :location
      t.date :start_date
      t.date :end_date
      t.boolean :current, null: false, default: false
      t.jsonb :responsibilities, null: false, default: []
      t.jsonb :achievements, null: false, default: []
      t.jsonb :technologies, null: false, default: []
      t.integer :position, null: false, default: 0

      t.timestamps
    end

    create_table :educations do |t|
      t.references :resume, null: false, foreign_key: true
      t.string :institution, null: false
      t.string :degree
      t.string :field_of_study
      t.integer :start_year
      t.integer :end_year
      t.string :gpa
      t.string :honors
      t.integer :position, null: false, default: 0

      t.timestamps
    end

    create_table :certifications do |t|
      t.references :resume, null: false, foreign_key: true
      t.string :name, null: false
      t.string :issuer
      t.date :issue_date
      t.date :expiry_date
      t.string :url
      t.integer :position, null: false, default: 0

      t.timestamps
    end

    create_table :skills do |t|
      t.references :resume, null: false, foreign_key: true
      t.string :name, null: false
      t.string :category, null: false, default: 'technical'
      t.integer :position, null: false, default: 0

      t.timestamps
    end

    create_table :projects do |t|
      t.references :resume, null: false, foreign_key: true
      t.string :title, null: false
      t.text :description
      t.string :url
      t.string :date
      t.string :role
      t.integer :position, null: false, default: 0

      t.timestamps
    end

    add_index :resumes, %i[user_id status]
    add_index :skills, %i[resume_id category]
  end
end
