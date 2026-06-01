# frozen_string_literal: true

module API
  module V1
    class EducationsController < API::V1::APIController
      before_action :set_resume
      before_action :set_education, only: %i[update destroy]

      def create
        authorize @resume, :update?
        @education = @resume.educations.create!(education_params)
        render :show, status: :created
      end

      def update
        authorize @resume, :update?
        @education.update!(education_params)
        render :show
      end

      def destroy
        authorize @resume, :update?
        @education.destroy!
        head :no_content
      end

      private

      def set_resume
        @resume = policy_scope(Resume).find(params[:resume_id])
      end

      def set_education
        @education = @resume.educations.find(params[:id])
      end

      def education_params
        params.expect(
          education: %i[institution degree field_of_study start_year end_year gpa honors position]
        )
      end
    end
  end
end
