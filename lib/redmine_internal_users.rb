# frozen_string_literal: true

module RedmineInternalUsers
  # Raised when the directory cannot be queried
  class DirectoryError < StandardError; end

  class << self
    # The source telling which users are internal, registered by another plugin.
    # It must respond to:
    # * internal_mails(mails): the given addresses that belong to internal users,
    #   downcased; it raises an error when the source cannot be queried, so that
    #   a failure is never mistaken for "not found"
    # * internal_details(mails), optional: lines describing the matching entries,
    #   displayed to administrators when they check a user
    # Without a directory, nobody is promoted.
    attr_accessor :directory
  end
end
