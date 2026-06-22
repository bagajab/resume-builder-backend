# frozen_string_literal: true

# Authorization for the shared lookups endpoint. Reading the curated option lists
# is open to any authenticated user; suggesting a new value requires a signed-in
# user (the submission is attributed to them and held for admin approval).
# Editing/deleting/approving options happens in ActiveAdmin, not the API.
class LookupPolicy < ApplicationPolicy
  def index?
    true
  end

  def create?
    user.present?
  end
end
