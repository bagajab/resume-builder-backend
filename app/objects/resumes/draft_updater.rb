# frozen_string_literal: true

module Resumes
  class DraftUpdater
    def initialize(resume, params)
      @resume = resume
      @params = params
    end

    def call
      ActiveRecord::Base.transaction do
        @resume.assign_attributes(resume_attributes)
        @resume.save!

        upsert_profile if profile_attributes.present?
        sync_collection(:experiences, experiences_attributes)
        sync_collection(:educations, educations_attributes)
        sync_collection(:certifications, certifications_attributes)
        sync_collection(:skills, skills_attributes)
        sync_collection(:projects, projects_attributes)
      end

      @resume.reload
    end

    private

    def resume_attributes
      attrs = @params.slice(:title, :current_step, :status, :layout_config).compact
      Resumes::TemplateResolver.apply_template_slug!(@resume, @params[:template_id]) if @params[:template_id].present?
      attrs
    end

    def profile_attributes
      @params[:profile]
    end

    def experiences_attributes
      @params[:experiences]
    end

    def educations_attributes
      @params[:educations]
    end

    def certifications_attributes
      @params[:certifications]
    end

    def skills_attributes
      @params[:skills]
    end

    def projects_attributes
      @params[:projects]
    end

    def upsert_profile
      profile = @resume.profile || @resume.build_profile
      profile.assign_attributes(profile_attributes)
      profile.save!
    end

    def sync_collection(association, items)
      return if items.nil?

      records = @resume.public_send(association)
      incoming_ids = []

      items.each_with_index do |item, index|
        attrs = item.to_h.symbolize_keys
        destroy = attrs.delete(:_destroy)
        attrs[:position] = index

        if attrs[:id].present?
          record = records.find(attrs[:id])
          incoming_ids << record.id
          destroy ? record.destroy! : record.update!(attrs.except(:id))
        elsif !destroy
          record = records.create!(attrs.except(:id))
          incoming_ids << record.id
        end
      end

      records.where.not(id: incoming_ids).destroy_all if items.is_a?(Array)
    end
  end
end
