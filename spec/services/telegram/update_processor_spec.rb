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

  describe 'callback_query feedback' do
    let(:user) { create(:user) }
    let(:job_alert) { create(:job_alert, user:) }
    let(:notification) do
      create(:job_alert_notification, :sent, user:, job_alert:, telegram_message_id: 1001)
    end

    before do
      create(:telegram_connection, :linked, user:, telegram_user_id: 42, telegram_chat_id: 555)
      allow(client).to receive(:answer_callback_query)
      allow(client).to receive(:edit_message_reply_markup)
    end

    def callback(data:, from_id: 42)
      process(
        callback_query: {
          id: 'cb1', data:, from: { id: from_id },
          message: { message_id: 1001, chat: { id: 555 } }
        }
      )
    end

    it 'records positive feedback and strips the feedback buttons' do
      callback(data: "fb:up:#{notification.id}")

      expect(notification.reload.feedback).to eq('positive')
      expect(client).to have_received(:answer_callback_query).with(hash_including(callback_query_id: 'cb1'))
      expect(client).to have_received(:edit_message_reply_markup)
    end

    it 'records negative feedback, mints a refine token, and offers the Mini App' do
      callback(data: "fb:down:#{notification.id}")

      notification.reload
      expect(notification.feedback).to eq('negative')
      expect(notification.refine_token_jti).to be_present
      expect(client).to have_received(:edit_message_reply_markup)
    end

    it 'rejects a tap from a different telegram user' do
      callback(data: "fb:up:#{notification.id}", from_id: 9999)

      expect(notification.reload.feedback).to be_nil
      expect(client).to have_received(:answer_callback_query).with(hash_including(show_alert: true))
      expect(client).not_to have_received(:edit_message_reply_markup)
    end

    it 'does not record feedback twice' do
      notification.record_feedback!('positive')

      callback(data: "fb:down:#{notification.id}")

      expect(notification.reload.feedback).to eq('positive')
      expect(client).not_to have_received(:edit_message_reply_markup)
    end

    it 'ignores callback data that is not a feedback action' do
      callback(data: 'something:else')

      expect(client).not_to have_received(:answer_callback_query)
    end
  end
end
