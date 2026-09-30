# frozen_string_literal: true

RedmineApp::Application.routes.draw do
  post 'users/:id/internal_status', :to => 'internal_status#check', :as => :check_user_internal_status
end
