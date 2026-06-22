# frozen_string_literal: true

module API
  module V1
    # Read + suggest endpoint backing every dropdown in the resume editor. One
    # controller dispatches to the right lookup table via a whitelisted slug, so we
    # don't repeat a near-identical controller eleven times.
    class LookupsController < API::V1::APIController
      # URL slug → model. Anything not in here is a 404.
      REGISTRY = {
        'country' => Country,
        'city' => City,
        'job_title' => JobTitle,
        'industry' => Industry,
        'degree' => Degree,
        'field_of_study' => FieldOfStudy,
        'skill' => SkillOption,
        'technology' => Technology,
        'language' => Language,
        'language_proficiency' => LanguageProficiency,
        'interest' => Interest
      }.freeze

      skip_after_action :verify_policy_scoped, only: :index

      def index
        authorize model, :index?, policy_class: LookupPolicy
        @options = scoped_options
      end

      def create
        authorize model, :create?, policy_class: LookupPolicy
        @option = upsert_option
        render :show, status: @option.previously_new_record? ? :created : :ok
      end

      private

      def model
        @model ||= REGISTRY.fetch(params[:list]) { raise ActiveRecord::RecordNotFound }
      end

      # Find an existing option (idempotent for repeat submissions) or create a new
      # one. End-user contributions land as `pending`; an admin promotes them to
      # `approved` (shared with everyone) in ActiveAdmin.
      def upsert_option
        option = model.find_or_initialize_by(normalized_value: model.normalize_value(value_param), **category_scope)
        if option.new_record?
          option.assign_attributes(value: value_param, status: 'pending', submitted_by_user: current_user)
          option.save!
        end
        option
      end

      def scoped_options
        base = model.by_category(params[:category])
        approved = finalize(base.approved)
        # Surface the user's own pending submissions first so a value they just
        # added is immediately selectable, even before approval.
        own_pending = finalize(base.pending.where(submitted_by_user: current_user))
        (own_pending + approved).uniq(&:id).first(20)
      end

      def finalize(scope)
        q = params[:q].to_s.strip
        relation = q.present? ? scope.search(q) : scope.ordered.limit(20)
        relation.to_a
      end

      def category_scope
        return {} unless model.column_names.include?('category')

        { category: params[:category].presence || SkillOption::CATEGORIES.first }
      end

      def value_param
        params.require(:value)
      end
    end
  end
end
