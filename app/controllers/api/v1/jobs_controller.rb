# frozen_string_literal: true

module API
  module V1
    class JobsController < API::V1::APIController
      def index
        authorize Job
        page = Jobs::Query.call(policy_scope(Job), params)
        @jobs = page.records
        @meta = page.meta
      end

      def show
        @job = Job.find(params.expect(:id))
        authorize @job
      end

      # Distinct values for building the filter UI.
      def filters
        authorize Job, :index?
        base = policy_scope(Job).live
        @filters = {
          sources: Job::SOURCES,
          employment_types: distinct_values(base, :employment_type),
          categories: distinct_values(base, :category),
          locations: distinct_values(base, :location)
        }
      end

      private

      def distinct_values(scope, column)
        scope.where.not(column => nil).distinct.pluck(column).compact.sort
      end
    end
  end
end
