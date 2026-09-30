# frozen_string_literal: true

# Refreshes the internal status of users from the registered directory.
# By default it only demotes internal users who left the directory; with seed it
# also promotes. Users are looked up like InternalUserStatus.lookup_mails.
class InternalUserSync
  class TooManyDemotions < StandardError; end

  MAX_DEMOTION_RATIO = 0.1

  attr_reader :promoted, :demoted, :checked

  def initialize(seed: false, force: false, directory: RedmineInternalUsers.directory)
    @seed = seed
    @force = force
    @directory = directory
  end

  # Raises RedmineInternalUsers::DirectoryError or TooManyDemotions before writing anything
  def run
    raise RedmineInternalUsers::DirectoryError, 'no directory registered' if @directory.nil?

    users = User.logged.active.where(internal_forced: nil)
    users = users.where(internal: true) unless @seed
    rows = users.pluck(:id, :internal, :internal_mail)
    internal_by_id = rows.to_h { |id, internal, _| [id, internal] }
    verified_mails = rows.filter_map { |id, _, mail| [id, [mail.downcase]] if mail.present? }.to_h
    mails_by_user_id = EmailAddress.where(user_id: internal_by_id.keys - verified_mails.keys).pluck(:user_id, :address)
                                   .group_by(&:first).transform_values { |pairs| pairs.map { |_, address| address.downcase } }
                                   .merge(verified_mails)

    found = internal_mails(mails_by_user_id.values.flatten)
    found_ids = mails_by_user_id.select { |_, mails| mails.any? { |mail| found.include?(mail) } }.keys.to_set

    @checked = internal_by_id.keys
    @promoted = @seed ? internal_by_id.reject { |id, internal| internal || found_ids.exclude?(id) }.keys : []
    @demoted = internal_by_id.select { |id, internal| internal && found_ids.exclude?(id) }.keys
    check_demotion_ratio(internal_by_id.values.count(true))

    now = Time.current
    User.where(id: @promoted).update_all(internal: true, internal_checked_at: now)
    User.where(id: @demoted).update_all(internal: false, internal_checked_at: now)
    User.where(id: @checked - @promoted - @demoted).update_all(internal_checked_at: now)
    self
  end

  private

  def internal_mails(mails)
    @directory.internal_mails(mails).to_set
  rescue StandardError => e
    raise RedmineInternalUsers::DirectoryError, e.message.presence || e.class.name
  end

  def check_demotion_ratio(internal_count)
    return if @force || @demoted.size <= internal_count * MAX_DEMOTION_RATIO

    raise TooManyDemotions,
          "#{@demoted.size} of #{internal_count} internal users would be demoted, run again with FORCE=1 to confirm"
  end
end
