# frozen_string_literal: true

Rails.application.routes.draw do
  root to: 'root#show'

  scope format: :json do
    mount_devise_token_auth_for 'User', at: '/api/v1/users', controllers: {
      registrations: 'api/v1/registrations',
      sessions: 'api/v1/sessions',
      passwords: 'api/v1/passwords'
    }
  end

  namespace :api do
    namespace :v1, defaults: { format: :json } do
      get :status, to: 'health#status'
      resources :impersonations, only: %i[create], constraints: Impersonation::EnabledConstraint.new
      devise_scope :user do
        resource :user, only: %i[update show]
        post 'users/oauth/google', to: 'oauth#google'
        post 'users/oauth/facebook', to: 'oauth#facebook'
      end

      resources :templates, only: %i[index]

      get 'public/profiles/:slug', to: 'public_profiles#show', as: :public_profile
      get 'public/profiles/:slug/export_pdf', to: 'public_profiles#export_pdf', as: :public_profile_export_pdf

      resources :resumes do
        collection do
          get :check_public_slug
        end
        member do
          patch :draft
          patch :public_profile
          get :export_pdf
          post :duplicate
        end

        resource :profile, only: %i[create update], controller: 'resume_profiles' do
          resource :photo, only: %i[create destroy], controller: 'profile_photos'
        end
        resources :experiences, only: %i[create update destroy]
        resources :educations, only: %i[create update destroy]
        resources :certifications, only: %i[create update destroy]
        resources :skills, only: %i[create update destroy]
        resources :projects, only: %i[create update destroy]
      end
      resources :settings, only: [] do
        get :must_update, on: :collection
      end
    end
  end

  devise_for :admin_users, ActiveAdmin::Devise.config
  ActiveAdmin.routes(self)
  namespace :admin do
    authenticate(:admin_user) do
      mount Flipper::UI.app(Flipper) => '/feature-flags'
      mount GoodJob::Engine => '/background-jobs'
    end
  end

  mount Rswag::Ui::Engine => '/api-docs'
  mount Rswag::Api::Engine => '/api-docs'
end
