# frozen_string_literal: true

class ResumePolicy < ApplicationPolicy
  class Scope < Scope
    def resolve
      scope.where(user_id: user.id)
    end
  end

  def index?
    true
  end

  def show?
    owner?
  end

  def create?
    true
  end

  def update?
    owner?
  end

  def destroy?
    owner?
  end

  def draft?
    owner?
  end

  def export_pdf?
    owner?
  end

  def duplicate?
    owner?
  end

  private

  def owner?
    record.user_id == user.id
  end
end
