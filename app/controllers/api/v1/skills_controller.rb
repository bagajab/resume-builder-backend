# frozen_string_literal: true

module API
  module V1
    class SkillsController < API::V1::APIController
      before_action :set_resume
      before_action :set_skill, only: %i[update destroy]

      def create
        authorize @resume, :update?
        @skill = @resume.skills.create!(skill_params)
        render :show, status: :created
      end

      def update
        authorize @resume, :update?
        @skill.update!(skill_params)
        render :show
      end

      def destroy
        authorize @resume, :update?
        @skill.destroy!
        head :no_content
      end

      private

      def set_resume
        @resume = policy_scope(Resume).find(params[:resume_id])
      end

      def set_skill
        @skill = @resume.skills.find(params[:id])
      end

      def skill_params
        params.expect(skill: %i[name category position])
      end
    end
  end
end
