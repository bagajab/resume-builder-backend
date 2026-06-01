# frozen_string_literal: true

module API
  module V1
    class ResumesController < API::V1::APIController
      before_action :set_resume, only: %i[show update destroy draft export_pdf duplicate]

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

      private

      def set_resume
        @resume = policy_scope(Resume).includes(
          :template,
          :profile,
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
        params.expect(resume: %i[title status current_step template_id layout_config])
      end

      def draft_params
        params.require(:resume).permit(
          :title, :current_step, :status, :template_id,
          layout_config: [
            :accent_color,
            :heading_color,
            :body_color,
            :muted_color,
            :background_color,
            :border_color,
            :columns,
            { section_order: [], hidden_sections: [],
              grid: [:columns, :row_height, { items: %i[section_id col row col_span row_span] }] }
          ],
          profile: [
            :full_name, :phone, :location_city, :location_country,
            :linkedin_url, :github_url, :portfolio_url,
            :job_title, :years_of_experience, :industry, :career_summary,
            { languages: %i[name proficiency],
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
          skills: [:id, :name, :category, :_destroy],
          projects: [:id, :title, :description, :url, :date, :role, :_destroy]
        ).to_h.deep_symbolize_keys
      end
    end
  end
end
