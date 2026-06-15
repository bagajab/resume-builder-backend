# frozen_string_literal: true

# Aggregated job listings are readable by any authenticated user.
class JobPolicy < ApplicationPolicy
  class Scope < Scope
    def resolve
      scope.all
    end
  end

  def index?
    true
  end

  def show?
    true
  end
end
