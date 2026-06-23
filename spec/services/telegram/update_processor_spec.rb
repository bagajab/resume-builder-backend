# frozen_string_literal: true

describe Telegram::UpdateProcessor do
  let(:client) { instance_double(Telegram::Client, send_message: nil) }

  def process(update)
    described_class.new(update, client:).call
  end

  describe '/start with a valid token' do
    let!(:connection) { create(:telegram_connection, link_token: 'tok123', link_token_expires_at: 30.minutes.from_now) }

    let(:update) do
      { message: { chat: { id: 555 }, from: { id: 42, username: 'bob' }, text: '/start tok123' } }
    end

    it 'stores the chat id and asks for the phone number' do
      process(update)

      connection.reload
      expect(connection.telegram_chat_id).to eq(555)
      expect(connection.telegram_user_id).to eq(42)
      expect(client).to have_received(:send_message).with(hash_including(chat_id: 555, reply_markup: anything))
    end
  end

  describe '/start with an invalid token' do
    let(:update) { { message: { chat: { id: 555 }, text: '/start nope' } } }

    it 'replies with an error and links nothing' do
      process(update)
      expect(client).to have_received(:send_message).with(hash_including(chat_id: 555))
      expect(TelegramConnection.where(telegram_chat_id: 555)).to be_empty
    end
  end

  describe 'sharing an Ethiopian contact' do
    let!(:connection) do
      create(:telegram_connection, telegram_chat_id: 555, telegram_user_id: 42, status: :pending)
    end

    let(:update) do
      { message: { chat: { id: 555 }, contact: { phone_number: '0911223344', user_id: 42 } } }
    end

    it 'verifies the phone and links the account' do
      process(update)

      connection.reload
      expect(connection).to be_linked
      expect(connection.phone_verified).to be(true)
      expect(connection.phone_number).to eq('+251911223344')
    end
  end

  describe 'sharing a non-Ethiopian contact' do
    let!(:connection) do
      create(:telegram_connection, telegram_chat_id: 555, telegram_user_id: 42, status: :pending)
    end

    let(:update) do
      { message: { chat: { id: 555 }, contact: { phone_number: '+15551234567', user_id: 42 } } }
    end

    it 'does not link the account' do
      process(update)
      expect(connection.reload).not_to be_linked
      expect(connection.phone_verified).to be(false)
    end
  end
end
