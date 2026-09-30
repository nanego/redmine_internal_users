# frozen_string_literal: true

module RedmineInternalUsers
  class Hooks < Redmine::Hook::Listener
    def controller_account_success_authentication_after(context = {})
      InternalUserStatus.refresh_after_login(context[:user], context[:request])
    end
  end

  class ModelHook < Redmine::Hook::Listener
    def after_plugins_loaded(_context = {})
      require_relative 'user_patch'
      require_relative 'user_query_patch'
    end
  end
end
