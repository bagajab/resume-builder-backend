# frozen_string_literal: true

describe Users::OauthService do
  describe '.find_or_create_user!' do
    let(:profile) do
      described_class::Profile.new(
        provider: 'google_oauth2',
        uid: 'google-sub-id',
        email: 'user@example.com',
        first_name: 'Google',
        last_name: 'User'
      )
    end

    context 'when an email account already exists' do
      let!(:existing_user) do
        create(:user, email: 'user@example.com', provider: 'email', uid: 'user@example.com')
      end

      it 'returns the existing user without changing provider' do
        user = described_class.find_or_create_user!(profile)

        expect(user).to eq(existing_user)
        expect(user.reload.provider).to eq('email')
      end

      it 'does not create a duplicate user' do
        expect {
          described_class.find_or_create_user!(profile)
        }.not_to change(User, :count)
      end
    end

    context 'when a different OAuth provider already exists for the email' do
      let!(:existing_user) do
        create(:user, email: 'user@example.com', provider: 'facebook', uid: 'facebook-id')
      end

      let(:profile) do
        described_class::Profile.new(
          provider: 'google_oauth2',
          uid: 'google-sub-id',
          email: 'user@example.com',
          first_name: 'Google',
          last_name: 'User'
        )
      end

      it 'returns the existing user' do
        expect(described_class.find_or_create_user!(profile)).to eq(existing_user)
      end
    end
  end
end
