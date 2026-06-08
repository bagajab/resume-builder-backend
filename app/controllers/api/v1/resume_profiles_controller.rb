# frozen_string_literal: true

module API
  module V1
    class ResumeProfilesController < API::V1::APIController
      before_action :set_resume

      def create
        authorize @resume, :update?
        profile = @resume.build_profile(profile_params)
        profile.save!
        @profile = profile
        render :show, status: :created
      end

      def update
        authorize @resume, :update?
        @profile = @resume.profile || @resume.build_profile
        @profile.update!(profile_params)
        render :show
      end

      private

      def set_resume
        @resume = policy_scope(Resume).find(params[:resume_id])
      end

      def profile_params
        params.expect(
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
          ]
        )
      end
    end
  end
end
