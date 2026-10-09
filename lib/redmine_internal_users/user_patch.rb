# frozen_string_literal: true

require_dependency 'principal'
require_dependency 'user'

module RedmineInternalUsers
  module UserPatch
    def self.prepended(base)
      base.class_eval do
        safe_attributes 'internal_forced', :if => lambda { |_user, current_user| current_user.admin? }
      end
    end

    # The status forced by an administrator wins over the one computed from the directory
    def internal_user?
      return false if new_record? || anonymous?

      internal_forced.nil? ? internal? : internal_forced
    end
    alias_method :internal_user, :internal_user?

    # How the status is set: 'auto' (from the directory), or forced to 'internal' or 'external'
    def internal_status_mode
      case internal_forced
      when nil then 'auto'
      when true then 'internal'
      else 'external'
      end
    end
  end
end

User.prepend RedmineInternalUsers::UserPatch
