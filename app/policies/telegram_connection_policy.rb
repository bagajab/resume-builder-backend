# frozen_string_literal: true

class TelegramConnectionPolicy < ApplicationPolicy
  def show? = owner?
  def create? = owner?
  def destroy? = owner?

  private

  def owner?
    record.user_id == user.id
  end
end
