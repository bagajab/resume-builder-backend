# frozen_string_literal: true

module API
  module V1
    class ProfilePhotosController < API::V1::APIController
      before_action :set_resume

      def create
        authorize @resume, :update?
        profile = @resume.profile || @resume.build_profile
        profile.photo.attach(params.expect(:photo))
        profile.save!
        render_resume
      end

      def destroy
        authorize @resume, :update?
        @resume.profile&.photo&.purge
        render_resume
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
        ).find(params[:resume_id])
      end

      def render_resume
        @resume.reload
        render 'api/v1/resumes/show'
      end
    end
  end
end
