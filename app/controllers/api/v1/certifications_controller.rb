# frozen_string_literal: true

module API
  module V1
    class CertificationsController < API::V1::APIController
      before_action :set_resume
      before_action :set_certification, only: %i[update destroy]

      def create
        authorize @resume, :update?
        @certification = @resume.certifications.create!(certification_params)
        render :show, status: :created
      end

      def update
        authorize @resume, :update?
        @certification.update!(certification_params)
        render :show
      end

      def destroy
        authorize @resume, :update?
        @certification.destroy!
        head :no_content
      end

      private

      def set_resume
        @resume = policy_scope(Resume).find(params[:resume_id])
      end

      def set_certification
        @certification = @resume.certifications.find(params[:id])
      end

      def certification_params
        params.expect(certification: %i[name issuer issue_date expiry_date url position])
      end
    end
  end
end
