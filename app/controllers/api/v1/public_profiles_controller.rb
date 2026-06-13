# frozen_string_literal: true

module API
  module V1
    class PublicProfilesController < API::V1::APIController
      skip_before_action :authenticate_user!
      skip_after_action :verify_authorized
      skip_after_action :verify_policy_scoped

      before_action :set_public_resume, only: %i[show export_pdf]

      def show
        render 'api/v1/resumes/show'
      end

      def export_pdf
        pdf = Resumes::PdfGenerator.new(@resume).render
        filename = "#{@resume.public_slug || @resume.title.parameterize}-resume.pdf"
        send_data pdf,
                  filename:,
                  type: 'application/pdf',
                  disposition: 'attachment'
      end

      private

      def set_public_resume
        @resume = Resume.publicly_visible.includes(
          :template,
          { profile: { photo_attachment: :blob } },
          :experiences,
          :educations,
          :certifications,
          :skills,
          :projects
        ).find_by!(public_slug: params[:slug])
      end
    end
  end
end
