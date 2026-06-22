# frozen_string_literal: true

if Rails.env.development?
  AdminUser.find_or_create_by!(email: 'admin@example.com') do |admin|
    admin.password = 'password'
  end
end

Setting.find_or_create_by!(key: 'min_version') { |s| s.value = '0.0' }

require Rails.root.join('db/seeds/lookups')
Seeds::Lookups.seed!

require Rails.root.join('db/seeds/resume_data')
Seeds::ResumeData.seed!
