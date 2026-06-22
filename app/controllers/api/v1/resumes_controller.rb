# frozen_string_literal: true

module API
  module V1
    class ResumesController < API::V1::APIController
      before_action :set_resume, only: %i[show update destroy draft export_pdf duplicate public_profile]

      def index
        @resumes = policy_scope(Resume).ordered.includes(:profile, :template)
        authorize Resume
      end

      def show
        authorize @resume
      end

      def create
        @resume = current_user.resumes.build(create_params)
        apply_template_slug(@resume, params.dig(:resume, :template_id))
        authorize @resume
        @resume.save!
        render :show, status: :created
      end

      def update
        authorize @resume
        attrs = update_params
        apply_template_slug(@resume, attrs.delete(:template_id))
        @resume.update!(attrs)
        render :show
      end

      def destroy
        authorize @resume
        @resume.destroy!
        head :no_content
      end

      def draft
        authorize @resume, :draft?
        @resume = Resumes::DraftUpdater.new(@resume, draft_params).call
        render :show
      end

      def export_pdf
        authorize @resume, :export_pdf?
        pdf = Resumes::PdfGenerator.new(@resume).render
        send_data pdf,
                  filename: "#{@resume.title.parameterize}-resume.pdf",
                  type: 'application/pdf',
                  disposition: 'attachment'
      end

      def duplicate
        authorize @resume, :duplicate?
        @resume = @resume.duplicate_for(current_user)
        render :show, status: :created
      end

      def public_profile
        authorize @resume, :update?
        @resume.update!(public_profile_params)
        render :show
      end

      def check_public_slug
        authorize Resume
        slug = Resume.normalize_public_slug(params[:slug])
        resume_id = params[:resume_id].presence&.to_i
        available = Resume.slug_available?(slug, excluding_id: resume_id)

        render json: {
          slug:,
          available:,
          errors: slug_errors(slug, resume_id)
        }
      end

      private

      def set_resume
        @resume = policy_scope(Resume).includes(
          :template,
          { profile: { photo_attachment: :blob } },
          :experiences,
          :educations,
          :certifications,
          :skills,
          :projects
        ).find(params[:id])
      end

      def apply_template_slug(resume, slug)
        return if slug.blank?

        Resumes::TemplateResolver.apply_template_slug!(resume, slug)
      end

      def create_params
        params.expect(resume: [:title])
      end

      def update_params
        params.expect(resume: %i[title status current_step template_id layout_config public_slug public_profile_enabled])
      end

      def public_profile_params
        params.expect(resume: %i[public_slug public_profile_enabled])
      end

      def slug_errors(slug, resume_id)
        errors = []
        errors << 'Slug is required' if slug.blank?
        errors << 'Slug is reserved' if slug.present? && Resume::RESERVED_SLUGS.include?(slug)
        if slug.present? && !Resume::SLUG_FORMAT.match?(slug)
          errors << 'Slug must contain only lowercase letters, numbers, and hyphens'
        end
        errors << 'Slug is already taken' if slug.present? && !Resume.slug_available?(slug, excluding_id: resume_id)
        errors
      end

      def draft_params
        permitted = params.require(:resume).permit(
          :title, :current_step, :status, :template_id,
          layout_config: [
            :accent_color,
            :heading_color,
            :body_color,
            :muted_color,
            :background_color,
            :border_color,
            :columns,
            :divider_color,
            :bullet_icon,
            { section_order: [], hidden_sections: [], page_breaks: [],
              custom_sections: [:id, :title, :column, :layout, :heading_color, :bullet_icon,
                                 { items: [:text, :icon] }],
              grid: [:columns, :row_height, { items: %i[section_id col row col_span row_span] }] }
          ],
          profile: [
            :full_name, :phone, :location_city, :location_country,
            :linkedin_url, :github_url, :portfolio_url,
            :job_title, :years_of_experience, :industry, :career_summary,
            { languages: %i[name proficiency level color],
              awards: %i[title organization date],
              volunteer_experiences: %i[role organization description date],
              references: %i[name title contact email phone],
              interests: [],
              job_preferences: %i[remote hybrid onsite] }
          ],
          experiences: [
            :id, :job_title, :company, :location, :start_date, :end_date, :current, :_destroy,
            { responsibilities: [], achievements: [], technologies: [] }
          ],
          educations: [
            :id, :institution, :degree, :field_of_study, :start_year, :end_year, :gpa, :honors, :_destroy
          ],
          certifications: [
            :id, :name, :issuer, :issue_date, :expiry_date, :url, :_destroy
          ],
          skills: [:id, :name, :category, :level, :color, :_destroy],
          projects: [:id, :title, :description, :url, :date, :role, :_destroy]
        ).to_h.deep_symbolize_keys

        merge_section_styles!(permitted)
        permitted
      end

      # section_styles is a hash keyed by dynamic section ids, so strong params
      # cannot enumerate the keys. It is purely cosmetic data stored as jsonb, so
      # we read it from the raw params and symbolize it manually.
      def merge_section_styles!(permitted)
        raw = params.dig(:resume, :layout_config, :section_styles)
        return if raw.blank?

        styles = raw.respond_to?(:to_unsafe_h) ? raw.to_unsafe_h : raw
        permitted[:layout_config] ||= {}
        permitted[:layout_config][:section_styles] = styles.deep_symbolize_keys
      end
    end
  end
end
