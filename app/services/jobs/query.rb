# frozen_string_literal: true

module Jobs
  # Translates request params into a filtered, sorted, paginated Job relation.
  # Keeps JobsController thin and the filter logic unit-testable.
  class Query
    PER_PAGE_DEFAULT = 20
    PER_PAGE_MAX = 50

    Page = Data.define(:records, :meta)

    def self.call(...)
      new(...).call
    end

    def initialize(scope, params)
      @scope = scope
      @params = params
    end

    def call
      relation = sorted(keyword(attributes(base)))
      meta = paginate(relation)
      Page.new(records: relation.offset(meta[:offset]).limit(meta[:per]), meta:)
    end

    private

    attr_reader :scope, :params

    def base
      params[:include_inactive] == 'true' ? scope : scope.live
    end

    def attributes(relation)
      relation = relation.from_source(params[:source]) if params[:source].present?
      relation = relation.where(employment_type: params[:employment_type]) if params[:employment_type].present?
      relation = relation.where(category: params[:category]) if params[:category].present?
      relation = relation.remote if params[:remote] == 'true'
      relation
    end

    def keyword(relation)
      relation = relation.open_for_application if params[:open] == 'true'
      relation = relation.search(params[:q]) if params[:q].present?
      return relation if params[:location].blank?

      relation.where('location ILIKE ?', "%#{Job.sanitize_sql_like(params[:location])}%")
    end

    def sorted(relation)
      case params[:sort]
      when 'deadline'
        relation.where.not(deadline_on: nil).order(deadline_on: :asc)
      else
        relation.recent
      end
    end

    def paginate(relation)
      per = bounded(:per, PER_PAGE_DEFAULT, PER_PAGE_MAX)
      page = bounded(:page, 1, 10_000)
      total = relation.count
      { page:, per:, total:, total_pages: total.fdiv(per).ceil, offset: (page - 1) * per }
    end

    def bounded(key, default, max)
      (params[key].presence || default).to_i.clamp(1, max)
    end
  end
end
