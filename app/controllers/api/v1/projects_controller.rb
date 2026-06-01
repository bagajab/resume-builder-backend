# frozen_string_literal: true

module API
  module V1
    class ProjectsController < API::V1::APIController
      before_action :set_resume
      before_action :set_project, only: %i[update destroy]

      def create
        authorize @resume, :update?
        @project = @resume.projects.create!(project_params)
        render :show, status: :created
      end

      def update
        authorize @resume, :update?
        @project.update!(project_params)
        render :show
      end

      def destroy
        authorize @resume, :update?
        @project.destroy!
        head :no_content
      end

      private

      def set_resume
        @resume = policy_scope(Resume).find(params[:resume_id])
      end

      def set_project
        @project = @resume.projects.find(params[:id])
      end

      def project_params
        params.expect(project: %i[title description url date role position])
      end
    end
  end
end
