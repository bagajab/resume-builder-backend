# frozen_string_literal: true

class JobAlertPolicy < ApplicationPolicy
  class Scope < Scope
    def resolve
      scope.where(user_id: user.id)
    end
  end

  def index? = true
  def create? = true
  def preview? = true
  def show? = owner?
  def update? = owner?
  def destroy? = owner?
  def pause? = owner?
  def resume? = owner?
  def notifications? = owner?

  private

  def owner?
    record.user_id == user.id
  end
end
