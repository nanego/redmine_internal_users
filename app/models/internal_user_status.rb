# frozen_string_literal: true

# Refreshes the internal status of one user from the registered directory
module InternalUserStatus
  # Logins whose mail claim has been verified by the identity provider
  TRUSTED_PROVIDERS = %w(openid_connect).freeze
  LOGIN_TIMEOUT = 5 # seconds
  CHECK_TIMEOUT = 10 # seconds

  module_function

  def directory
    RedmineInternalUsers.directory
  end

  # Called after a successful login. Only an OIDC login is trusted: users can edit
  # the addresses of their own account. Never breaks the login: on failure, the
  # previous status is kept.
  def refresh_after_login(user, request)
    return if directory.nil? || !user.internal_forced.nil?

    auth = request&.env&.[]('omniauth.auth')
    return unless auth && TRUSTED_PROVIDERS.include?(auth['provider'].to_s)

    mail = auth.dig('info', 'email').to_s.strip.downcase
    return if mail.blank?

    internal = Timeout.timeout(LOGIN_TIMEOUT) { directory.internal_mails([mail]).any? }
    user.update_columns(internal: internal, internal_mail: mail, internal_checked_at: Time.current)
  rescue StandardError => e
    Rails.logger.warn "WARNING (redmine_internal_users): internal status of #{user.login} not refreshed: #{e.message}"
  end

  # Checks a user on the request of an administrator. A forced status is left
  # untouched. Returns the addresses looked up, those found, and the details
  # given by the directory. Raises RedmineInternalUsers::DirectoryError.
  def check!(user)
    raise RedmineInternalUsers::DirectoryError, 'no directory registered' if directory.nil?

    mails = lookup_mails(user)
    found, details = Timeout.timeout(CHECK_TIMEOUT) do
      [directory.internal_mails(mails).to_set & mails,
       directory.respond_to?(:internal_details) ? directory.internal_details(mails) : []]
    end
    changed = false
    if user.internal_forced.nil?
      changed = user.internal? != found.any?
      user.update_columns(internal: found.any?, internal_checked_at: Time.current)
    end
    { mails: mails, found: found, details: details, changed: changed }
  rescue RedmineInternalUsers::DirectoryError
    raise
  rescue StandardError => e
    raise RedmineInternalUsers::DirectoryError, e.message.presence || e.class.name
  end

  # The address verified at the last OIDC login wins over the addresses of the
  # account, which may differ when the user was matched on another claim
  def lookup_mails(user)
    mails = user.internal_mail.present? ? [user.internal_mail] : user.mails
    mails.map { |mail| mail.to_s.strip.downcase }.compact_blank.uniq
  end
end
