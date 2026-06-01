# frozen_string_literal: true

module API
  module V1
    class ExperiencesController < API::V1::APIController
      before_action :set_resume
      before_action :set_experience, only: %i[update destroy]

      def create
        authorize @resume, :update?
        @experience = @resume.experiences.create!(experience_params)
        render :show, status: :created
      end

      def update
        authorize @resume, :update?
        @experience.update!(experience_params)
        render :show
      end

      def destroy
        authorize @resume, :update?
        @experience.destroy!
        head :no_content
      end

      private

      def set_resume
        @resume = policy_scope(Resume).find(params[:resume_id])
      end

      def set_experience
        @experience = @resume.experiences.find(params[:id])
      end

      def experience_params
        params.expect(
          experience: [
            :job_title, :company, :location, :start_date, :end_date, :current, :position,
            { responsibilities: [], achievements: [], technologies: [] }
          ]
        )
      end
    end
  end
end
