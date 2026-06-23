# frozen_string_literal: true

describe JobAlertPolicy do
  subject { described_class }

  let(:owner) { create(:user) }
  let(:other) { create(:user) }
  let(:alert) { create(:job_alert, user: owner) }

  permissions :show?, :update?, :destroy?, :pause?, :resume?, :notifications? do
    it 'grants the owner' do
      expect(subject).to permit(owner, alert)
    end

    it 'denies a non-owner' do
      expect(subject).not_to permit(other, alert)
    end
  end

  permissions :create?, :preview?, :index? do
    it 'is allowed for any authenticated user' do
      expect(subject).to permit(other, JobAlert.new)
    end
  end

  describe 'Scope' do
    it 'returns only the user own alerts' do
      mine = create(:job_alert, user: owner)
      create(:job_alert, user: other)
      resolved = described_class::Scope.new(owner, JobAlert).resolve
      expect(resolved).to contain_exactly(mine, alert)
    end
  end
end
