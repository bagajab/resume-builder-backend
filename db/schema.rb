# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_06_20_000001) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"
  enable_extension "pg_trgm"

  create_table "active_storage_attachments", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.datetime "created_at", precision: nil, null: false
    t.string "name", null: false
    t.bigint "record_id", null: false
    t.string "record_type", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.string "content_type"
    t.datetime "created_at", precision: nil, null: false
    t.string "filename", null: false
    t.string "key", null: false
    t.text "metadata"
    t.string "service_name", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "admin_users", id: :serial, force: :cascade do |t|
    t.datetime "created_at", precision: nil, null: false
    t.datetime "current_sign_in_at", precision: nil
    t.inet "current_sign_in_ip"
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.datetime "last_sign_in_at", precision: nil
    t.inet "last_sign_in_ip"
    t.datetime "remember_created_at", precision: nil
    t.datetime "reset_password_sent_at", precision: nil
    t.string "reset_password_token"
    t.integer "sign_in_count", default: 0, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.index ["email"], name: "index_admin_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_admin_users_on_reset_password_token", unique: true
  end

  create_table "certifications", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.date "expiry_date"
    t.date "issue_date"
    t.string "issuer"
    t.string "name", null: false
    t.integer "position", default: 0, null: false
    t.bigint "resume_id", null: false
    t.datetime "updated_at", null: false
    t.string "url"
    t.index ["resume_id"], name: "index_certifications_on_resume_id"
  end

  create_table "cities", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "normalized_value", null: false
    t.integer "position", default: 0, null: false
    t.string "status", default: "approved", null: false
    t.bigint "submitted_by_user_id"
    t.datetime "updated_at", null: false
    t.integer "usage_count", default: 0, null: false
    t.string "value", null: false
    t.index ["normalized_value"], name: "index_cities_on_normalized_value", unique: true
    t.index ["status"], name: "index_cities_on_status"
    t.index ["submitted_by_user_id"], name: "index_cities_on_submitted_by_user_id"
    t.index ["value"], name: "index_cities_on_value_trgm", opclass: :gin_trgm_ops, using: :gin
  end

  create_table "countries", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "normalized_value", null: false
    t.integer "position", default: 0, null: false
    t.string "status", default: "approved", null: false
    t.bigint "submitted_by_user_id"
    t.datetime "updated_at", null: false
    t.integer "usage_count", default: 0, null: false
    t.string "value", null: false
    t.index ["normalized_value"], name: "index_countries_on_normalized_value", unique: true
    t.index ["status"], name: "index_countries_on_status"
    t.index ["submitted_by_user_id"], name: "index_countries_on_submitted_by_user_id"
    t.index ["value"], name: "index_countries_on_value_trgm", opclass: :gin_trgm_ops, using: :gin
  end

  create_table "degrees", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "normalized_value", null: false
    t.integer "position", default: 0, null: false
    t.string "status", default: "approved", null: false
    t.bigint "submitted_by_user_id"
    t.datetime "updated_at", null: false
    t.integer "usage_count", default: 0, null: false
    t.string "value", null: false
    t.index ["normalized_value"], name: "index_degrees_on_normalized_value", unique: true
    t.index ["status"], name: "index_degrees_on_status"
    t.index ["submitted_by_user_id"], name: "index_degrees_on_submitted_by_user_id"
    t.index ["value"], name: "index_degrees_on_value_trgm", opclass: :gin_trgm_ops, using: :gin
  end

  create_table "educations", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "degree"
    t.integer "end_year"
    t.string "field_of_study"
    t.string "gpa"
    t.string "honors"
    t.string "institution", null: false
    t.integer "position", default: 0, null: false
    t.bigint "resume_id", null: false
    t.integer "start_year"
    t.datetime "updated_at", null: false
    t.index ["resume_id"], name: "index_educations_on_resume_id"
  end

  create_table "experiences", force: :cascade do |t|
    t.jsonb "achievements", default: [], null: false
    t.string "company", null: false
    t.datetime "created_at", null: false
    t.boolean "current", default: false, null: false
    t.date "end_date"
    t.string "job_title", null: false
    t.string "location"
    t.integer "position", default: 0, null: false
    t.jsonb "responsibilities", default: [], null: false
    t.bigint "resume_id", null: false
    t.date "start_date"
    t.jsonb "technologies", default: [], null: false
    t.datetime "updated_at", null: false
    t.index ["resume_id"], name: "index_experiences_on_resume_id"
  end

  create_table "fields_of_study", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "normalized_value", null: false
    t.integer "position", default: 0, null: false
    t.string "status", default: "approved", null: false
    t.bigint "submitted_by_user_id"
    t.datetime "updated_at", null: false
    t.integer "usage_count", default: 0, null: false
    t.string "value", null: false
    t.index ["normalized_value"], name: "index_fields_of_study_on_normalized_value", unique: true
    t.index ["status"], name: "index_fields_of_study_on_status"
    t.index ["submitted_by_user_id"], name: "index_fields_of_study_on_submitted_by_user_id"
    t.index ["value"], name: "index_fields_of_study_on_value_trgm", opclass: :gin_trgm_ops, using: :gin
  end

  create_table "flipper_features", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "key", null: false
    t.datetime "updated_at", null: false
    t.index ["key"], name: "index_flipper_features_on_key", unique: true
  end

  create_table "flipper_gates", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "feature_key", null: false
    t.string "key", null: false
    t.datetime "updated_at", null: false
    t.text "value"
    t.index ["feature_key", "key", "value"], name: "index_flipper_gates_on_feature_key_and_key_and_value", unique: true
  end

  create_table "good_job_batches", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.integer "callback_priority"
    t.text "callback_queue_name"
    t.datetime "created_at", null: false
    t.text "description"
    t.datetime "discarded_at"
    t.datetime "enqueued_at"
    t.datetime "finished_at"
    t.datetime "jobs_finished_at"
    t.text "on_discard"
    t.text "on_finish"
    t.text "on_success"
    t.jsonb "serialized_properties"
    t.datetime "updated_at", null: false
  end

  create_table "good_job_executions", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "active_job_id", null: false
    t.datetime "created_at", null: false
    t.interval "duration"
    t.text "error"
    t.text "error_backtrace", array: true
    t.integer "error_event", limit: 2
    t.datetime "finished_at"
    t.text "job_class"
    t.uuid "process_id"
    t.text "queue_name"
    t.datetime "scheduled_at"
    t.jsonb "serialized_params"
    t.datetime "updated_at", null: false
    t.index ["active_job_id", "created_at"], name: "index_good_job_executions_on_active_job_id_and_created_at"
    t.index ["process_id", "created_at"], name: "index_good_job_executions_on_process_id_and_created_at"
  end

  create_table "good_job_processes", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "lock_type", limit: 2
    t.jsonb "state"
    t.datetime "updated_at", null: false
  end

  create_table "good_job_settings", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "key"
    t.datetime "updated_at", null: false
    t.jsonb "value"
    t.index ["key"], name: "index_good_job_settings_on_key", unique: true
  end

  create_table "good_jobs", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "active_job_id"
    t.uuid "batch_callback_id"
    t.uuid "batch_id"
    t.text "concurrency_key"
    t.datetime "created_at", null: false
    t.datetime "cron_at"
    t.text "cron_key"
    t.text "error"
    t.integer "error_event", limit: 2
    t.integer "executions_count"
    t.datetime "finished_at"
    t.boolean "is_discrete"
    t.text "job_class"
    t.text "labels", array: true
    t.datetime "locked_at"
    t.uuid "locked_by_id"
    t.datetime "performed_at"
    t.integer "priority"
    t.text "queue_name"
    t.uuid "retried_good_job_id"
    t.datetime "scheduled_at"
    t.jsonb "serialized_params"
    t.datetime "updated_at", null: false
    t.index ["active_job_id", "created_at"], name: "index_good_jobs_on_active_job_id_and_created_at"
    t.index ["batch_callback_id"], name: "index_good_jobs_on_batch_callback_id", where: "(batch_callback_id IS NOT NULL)"
    t.index ["batch_id"], name: "index_good_jobs_on_batch_id", where: "(batch_id IS NOT NULL)"
    t.index ["concurrency_key", "created_at"], name: "index_good_jobs_on_concurrency_key_and_created_at"
    t.index ["concurrency_key"], name: "index_good_jobs_on_concurrency_key_when_unfinished", where: "(finished_at IS NULL)"
    t.index ["cron_key", "created_at"], name: "index_good_jobs_on_cron_key_and_created_at_cond", where: "(cron_key IS NOT NULL)"
    t.index ["cron_key", "cron_at"], name: "index_good_jobs_on_cron_key_and_cron_at_cond", unique: true, where: "(cron_key IS NOT NULL)"
    t.index ["finished_at"], name: "index_good_jobs_jobs_on_finished_at", where: "((retried_good_job_id IS NULL) AND (finished_at IS NOT NULL))"
    t.index ["labels"], name: "index_good_jobs_on_labels", where: "(labels IS NOT NULL)", using: :gin
    t.index ["locked_by_id"], name: "index_good_jobs_on_locked_by_id", where: "(locked_by_id IS NOT NULL)"
    t.index ["priority", "created_at"], name: "index_good_job_jobs_for_candidate_lookup", where: "(finished_at IS NULL)"
    t.index ["priority", "created_at"], name: "index_good_jobs_jobs_on_priority_created_at_when_unfinished", order: { priority: "DESC NULLS LAST" }, where: "(finished_at IS NULL)"
    t.index ["priority", "scheduled_at"], name: "index_good_jobs_on_priority_scheduled_at_unfinished_unlocked", where: "((finished_at IS NULL) AND (locked_by_id IS NULL))"
    t.index ["queue_name", "scheduled_at"], name: "index_good_jobs_on_queue_name_and_scheduled_at", where: "(finished_at IS NULL)"
    t.index ["scheduled_at"], name: "index_good_jobs_on_scheduled_at", where: "(finished_at IS NULL)"
  end

  create_table "industries", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "normalized_value", null: false
    t.integer "position", default: 0, null: false
    t.string "status", default: "approved", null: false
    t.bigint "submitted_by_user_id"
    t.datetime "updated_at", null: false
    t.integer "usage_count", default: 0, null: false
    t.string "value", null: false
    t.index ["normalized_value"], name: "index_industries_on_normalized_value", unique: true
    t.index ["status"], name: "index_industries_on_status"
    t.index ["submitted_by_user_id"], name: "index_industries_on_submitted_by_user_id"
    t.index ["value"], name: "index_industries_on_value_trgm", opclass: :gin_trgm_ops, using: :gin
  end

  create_table "interests", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "normalized_value", null: false
    t.integer "position", default: 0, null: false
    t.string "status", default: "approved", null: false
    t.bigint "submitted_by_user_id"
    t.datetime "updated_at", null: false
    t.integer "usage_count", default: 0, null: false
    t.string "value", null: false
    t.index ["normalized_value"], name: "index_interests_on_normalized_value", unique: true
    t.index ["status"], name: "index_interests_on_status"
    t.index ["submitted_by_user_id"], name: "index_interests_on_submitted_by_user_id"
    t.index ["value"], name: "index_interests_on_value_trgm", opclass: :gin_trgm_ops, using: :gin
  end

  create_table "job_titles", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "normalized_value", null: false
    t.integer "position", default: 0, null: false
    t.string "status", default: "approved", null: false
    t.bigint "submitted_by_user_id"
    t.datetime "updated_at", null: false
    t.integer "usage_count", default: 0, null: false
    t.string "value", null: false
    t.index ["normalized_value"], name: "index_job_titles_on_normalized_value", unique: true
    t.index ["status"], name: "index_job_titles_on_status"
    t.index ["submitted_by_user_id"], name: "index_job_titles_on_submitted_by_user_id"
    t.index ["value"], name: "index_job_titles_on_value_trgm", opclass: :gin_trgm_ops, using: :gin
  end

  create_table "jobs", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.string "apply_url"
    t.string "category"
    t.string "company_logo_url"
    t.string "company_name"
    t.datetime "created_at", null: false
    t.date "deadline_on"
    t.text "description"
    t.string "education_level"
    t.string "employment_type"
    t.string "experience_level"
    t.datetime "first_seen_at", null: false
    t.datetime "last_seen_at", null: false
    t.string "location"
    t.jsonb "metadata", default: {}, null: false
    t.date "posted_on"
    t.string "region"
    t.boolean "remote", default: false, null: false
    t.string "salary"
    t.string "source", null: false
    t.string "source_uid"
    t.text "summary"
    t.string "tags", default: [], null: false, array: true
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.string "url", null: false
    t.index ["active"], name: "index_jobs_on_active"
    t.index ["deadline_on"], name: "index_jobs_on_deadline_on"
    t.index ["posted_on"], name: "index_jobs_on_posted_on"
    t.index ["source", "source_uid"], name: "index_jobs_on_source_and_source_uid"
    t.index ["source"], name: "index_jobs_on_source"
    t.index ["tags"], name: "index_jobs_on_tags", using: :gin
    t.index ["url"], name: "index_jobs_on_url", unique: true
  end

  create_table "language_proficiencies", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "normalized_value", null: false
    t.integer "position", default: 0, null: false
    t.string "status", default: "approved", null: false
    t.bigint "submitted_by_user_id"
    t.datetime "updated_at", null: false
    t.integer "usage_count", default: 0, null: false
    t.string "value", null: false
    t.index ["normalized_value"], name: "index_language_proficiencies_on_normalized_value", unique: true
    t.index ["status"], name: "index_language_proficiencies_on_status"
    t.index ["submitted_by_user_id"], name: "index_language_proficiencies_on_submitted_by_user_id"
    t.index ["value"], name: "index_language_proficiencies_on_value_trgm", opclass: :gin_trgm_ops, using: :gin
  end

  create_table "languages", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "normalized_value", null: false
    t.integer "position", default: 0, null: false
    t.string "status", default: "approved", null: false
    t.bigint "submitted_by_user_id"
    t.datetime "updated_at", null: false
    t.integer "usage_count", default: 0, null: false
    t.string "value", null: false
    t.index ["normalized_value"], name: "index_languages_on_normalized_value", unique: true
    t.index ["status"], name: "index_languages_on_status"
    t.index ["submitted_by_user_id"], name: "index_languages_on_submitted_by_user_id"
    t.index ["value"], name: "index_languages_on_value_trgm", opclass: :gin_trgm_ops, using: :gin
  end

  create_table "projects", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "date"
    t.text "description"
    t.integer "position", default: 0, null: false
    t.bigint "resume_id", null: false
    t.string "role"
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.string "url"
    t.index ["resume_id"], name: "index_projects_on_resume_id"
  end

  create_table "resume_profiles", force: :cascade do |t|
    t.jsonb "awards", default: [], null: false
    t.text "career_summary"
    t.datetime "created_at", null: false
    t.string "full_name"
    t.string "github_url"
    t.string "industry"
    t.jsonb "interests", default: [], null: false
    t.jsonb "job_preferences", default: {}, null: false
    t.string "job_title"
    t.jsonb "languages", default: [], null: false
    t.string "linkedin_url"
    t.string "location_city"
    t.string "location_country"
    t.string "phone"
    t.string "portfolio_url"
    t.jsonb "references", default: [], null: false
    t.bigint "resume_id", null: false
    t.datetime "updated_at", null: false
    t.jsonb "volunteer_experiences", default: [], null: false
    t.integer "years_of_experience"
    t.index ["resume_id"], name: "index_resume_profiles_on_resume_id", unique: true
  end

  create_table "resumes", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "current_step", default: 1, null: false
    t.jsonb "layout_config", default: {}, null: false
    t.boolean "public_profile_enabled", default: false, null: false
    t.string "public_slug"
    t.datetime "published_at"
    t.bigint "source_resume_id"
    t.string "status", default: "draft", null: false
    t.bigint "template_id", null: false
    t.string "title", default: "Untitled Resume", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.integer "version", default: 1, null: false
    t.index ["public_profile_enabled"], name: "index_resumes_on_public_profile_enabled", where: "(public_profile_enabled = true)"
    t.index ["public_slug"], name: "index_resumes_on_public_slug", unique: true, where: "(public_slug IS NOT NULL)"
    t.index ["source_resume_id"], name: "index_resumes_on_source_resume_id"
    t.index ["template_id"], name: "index_resumes_on_template_id"
    t.index ["user_id", "status"], name: "index_resumes_on_user_id_and_status"
    t.index ["user_id"], name: "index_resumes_on_user_id"
  end

  create_table "settings", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "key", null: false
    t.datetime "updated_at", null: false
    t.string "value"
    t.index ["key"], name: "index_settings_on_key", unique: true
  end

  create_table "skill_options", force: :cascade do |t|
    t.string "category", default: "technical", null: false
    t.datetime "created_at", null: false
    t.string "normalized_value", null: false
    t.integer "position", default: 0, null: false
    t.string "status", default: "approved", null: false
    t.bigint "submitted_by_user_id"
    t.datetime "updated_at", null: false
    t.integer "usage_count", default: 0, null: false
    t.string "value", null: false
    t.index ["category"], name: "index_skill_options_on_category"
    t.index ["normalized_value", "category"], name: "index_skill_options_on_normalized_value_and_category", unique: true
    t.index ["status"], name: "index_skill_options_on_status"
    t.index ["submitted_by_user_id"], name: "index_skill_options_on_submitted_by_user_id"
    t.index ["value"], name: "index_skill_options_on_value_trgm", opclass: :gin_trgm_ops, using: :gin
  end

  create_table "skills", force: :cascade do |t|
    t.string "category", default: "technical", null: false
    t.string "color"
    t.datetime "created_at", null: false
    t.integer "level"
    t.string "name", null: false
    t.integer "position", default: 0, null: false
    t.bigint "resume_id", null: false
    t.datetime "updated_at", null: false
    t.index ["resume_id", "category"], name: "index_skills_on_resume_id_and_category"
    t.index ["resume_id"], name: "index_skills_on_resume_id"
  end

  create_table "technologies", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "normalized_value", null: false
    t.integer "position", default: 0, null: false
    t.string "status", default: "approved", null: false
    t.bigint "submitted_by_user_id"
    t.datetime "updated_at", null: false
    t.integer "usage_count", default: 0, null: false
    t.string "value", null: false
    t.index ["normalized_value"], name: "index_technologies_on_normalized_value", unique: true
    t.index ["status"], name: "index_technologies_on_status"
    t.index ["submitted_by_user_id"], name: "index_technologies_on_submitted_by_user_id"
    t.index ["value"], name: "index_technologies_on_value_trgm", opclass: :gin_trgm_ops, using: :gin
  end

  create_table "templates", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "description"
    t.string "name", null: false
    t.string "slug", null: false
    t.datetime "updated_at", null: false
    t.index ["slug"], name: "index_templates_on_slug", unique: true
  end

  create_table "users", id: :serial, force: :cascade do |t|
    t.boolean "allow_password_change", default: false, null: false
    t.datetime "created_at", precision: nil, null: false
    t.datetime "current_sign_in_at", precision: nil
    t.inet "current_sign_in_ip"
    t.string "email"
    t.string "encrypted_password", default: "", null: false
    t.string "first_name", default: ""
    t.string "last_name", default: ""
    t.datetime "last_sign_in_at", precision: nil
    t.inet "last_sign_in_ip"
    t.boolean "password_set", default: false, null: false
    t.string "provider", default: "email", null: false
    t.datetime "reset_password_sent_at", precision: nil
    t.string "reset_password_token"
    t.integer "sign_in_count", default: 0, null: false
    t.json "tokens"
    t.string "uid", default: "", null: false
    t.datetime "updated_at", precision: nil, null: false
    t.string "username", default: ""
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
    t.index ["uid", "provider"], name: "index_users_on_uid_and_provider", unique: true
  end

  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "certifications", "resumes"
  add_foreign_key "cities", "users", column: "submitted_by_user_id"
  add_foreign_key "countries", "users", column: "submitted_by_user_id"
  add_foreign_key "degrees", "users", column: "submitted_by_user_id"
  add_foreign_key "educations", "resumes"
  add_foreign_key "experiences", "resumes"
  add_foreign_key "fields_of_study", "users", column: "submitted_by_user_id"
  add_foreign_key "industries", "users", column: "submitted_by_user_id"
  add_foreign_key "interests", "users", column: "submitted_by_user_id"
  add_foreign_key "job_titles", "users", column: "submitted_by_user_id"
  add_foreign_key "language_proficiencies", "users", column: "submitted_by_user_id"
  add_foreign_key "languages", "users", column: "submitted_by_user_id"
  add_foreign_key "projects", "resumes"
  add_foreign_key "resume_profiles", "resumes"
  add_foreign_key "resumes", "resumes", column: "source_resume_id"
  add_foreign_key "resumes", "templates"
  add_foreign_key "resumes", "users"
  add_foreign_key "skill_options", "users", column: "submitted_by_user_id"
  add_foreign_key "skills", "resumes"
  add_foreign_key "technologies", "users", column: "submitted_by_user_id"
end
