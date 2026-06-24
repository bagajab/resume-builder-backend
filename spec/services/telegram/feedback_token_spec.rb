# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Telegram::FeedbackToken do
  let(:notification) { create(:job_alert_notification) }

  it 'round-trips the notification context and stamps a jti on the notification' do
    token = described_class.generate(notification, telegram_user_id: 999)
    payload = described_class.verify(token)

    expect(payload).to include(nid: notification.id, jaid: notification.job_alert_id, uid: 999)
    expect(notification.reload.refine_token_jti).to eq(payload[:jti])
  end

  it 'returns nil for a tampered or garbage token' do
    expect(described_class.verify('not-a-real-token')).to be_nil
    expect(described_class.verify(nil)).to be_nil
  end

  it 'expires after the TTL' do
    token = described_class.generate(notification, telegram_user_id: 999)

    travel_to((described_class::TTL + 1.minute).from_now) do
      expect(described_class.verify(token)).to be_nil
    end
  end

  it 'is single-use via the notification jti (active until consumed)' do
    token = described_class.generate(notification, telegram_user_id: 999)
    jti = described_class.verify(token).fetch(:jti)

    expect(notification.refine_token_active?(jti)).to be(true)

    notification.consume_refine_token!
    expect(notification.reload.refine_token_active?(jti)).to be(false)
  end

  it 'invalidates a prior token when a new one is generated' do
    first = described_class.verify(described_class.generate(notification, telegram_user_id: 999)).fetch(:jti)
    described_class.generate(notification, telegram_user_id: 999) # new jti

    expect(notification.reload.refine_token_active?(first)).to be(false)
  end
end
