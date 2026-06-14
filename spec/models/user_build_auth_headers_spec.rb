# frozen_string_literal: true

describe User do
  describe '#build_auth_headers' do
    let(:user) { create(:user) }

    it 'returns headers when the client entry was removed during token cleanup' do
      6.times { user.create_token }
      user.save!

      token = user.create_token
      user.save!

      headers = user.build_auth_headers(token.token, token.client)

      expect(headers['access-token']).to eq(token.token)
      expect(headers['client']).to eq(token.client)
      expect(headers['uid']).to eq(user.uid)
      expect(headers['expiry']).to be_present
    end
  end
end
