# frozen_string_literal: true

Rails.application.routes.draw do
  mount Ckeditor::Engine => '/ckeditor'
  apipie

  get '/healthcheck', to: 'application#healthcheck'
  get '/sample_pdf', to: 'application#sample_pdf', defaults: { format: :pdf }
  get '/sample_pdf_email', to: 'application#sample_pdf_email'

  unless Rails.env.production?
    get '/log-test', to: 'application#log_test'
  end

  root to: 'application#homepage'

  namespace :cms do
    root to: 'application#index'
    resources :hygiene_pages, only: %i[edit update]
    resources :users
    resources :samples do
      %i[
        images
        videos
        audios
      ].each do |resource|
        resources resource, controller: 'attachments', resource: resource.to_s, except: :show do
          collection do
            post '/update_order', to: 'attachments#update_order', resource: resource.to_s
            get '/mass_upload', to: 'attachments#mass_upload', resource: resource.to_s
          end
        end
      end
    end
  end

  devise_for :admin_users, skip: [:registrations]
  as :admin_user do
    get 'admin_users/edit', to: 'devise/registrations#edit', as: 'edit_admin_user_registration'
    patch 'admin_users', to: 'devise/registrations#update', as: 'admin_user_registration'
  end

  # code below is commented and the one below it is used to accommodate Createable test
  # devise_for :users, skip: :all
  devise_for :users

  namespace 'api' do
    post '/contact_form', to: 'base#contact_form'

    namespace 'experiment' do
      get '/send_emails', to: 'base#send_emails', defaults: { format: 'application/json' }
    end

    namespace 'v1' do
      # devise related
      post 'register', to: 'users#register'
      post 'resend-confirmation', to: 'users#resend_confirmation'
      post 'confirm', to: 'users#confirm'
      post 'forgot-password', to: 'users#forgot_password'
      post 'reset-password', to: 'users#reset_password'

      # duplicate paths to doorkeeper that is exposed on apipie
      # front end will use this for pretty purpose
      post 'login', to: 'tokens#login'
      post 'refresh', to: 'tokens#refresh'
      post 'logout', to: 'tokens#revoke'

      resources :samples, only: [:index], defaults: { format: :json }

      # users
      post 'update-profile', to: 'users#update_profile'
      post 'update-avatar', to: 'users#update_avatar'
      get 'get-profile', to: 'users#get_profile'
      post 'update-password', to: 'users#update_password'
    end
  end

  get '/:id', to: 'application#hygiene_page'
end
