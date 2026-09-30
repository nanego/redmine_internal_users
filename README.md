# Redmine Internal Users

## Test status

|Plugin branch| Redmine Version | Test Status       |
|-------------|-----------------|-------------------|
|master       | 6.1.4           | [![6.1.4][2]][5]  |
|master       | 7.0.1           | [![7.0.1][1]][5]  |
|master       | master          | [![master][3]][5] |

[1]: https://github.com/nanego/redmine_internal_users/actions/workflows/7_0_1.yml/badge.svg
[2]: https://github.com/nanego/redmine_internal_users/actions/workflows/6_1_4.yml/badge.svg
[3]: https://github.com/nanego/redmine_internal_users/actions/workflows/master.yml/badge.svg
[5]: https://github.com/nanego/redmine_internal_users/actions

Tells **internal** users (the staff of the organization running Redmine) from **external** ones (partners, contractors, the public), according to a directory such as an LDAP server or an HR service.

The status is exposed as `User#internal_user?`, so that other plugins can rely on it. For instance, [redmine_restricted_public](https://github.com/nanego/redmine_restricted_public) adds projects that are public for internal users only.

## Internal status

A user is internal when `users.internal_forced` is `true`, or when it is empty and `users.internal` is `true`. Anonymous and unsaved users are never internal.

- `internal` is computed from the directory (see below).
- `internal_forced` is set by an administrator on the user form: *Automatic*, *Forced: internal* or *Forced: external*. A forced status is never recomputed.

The user list has an "Internal" column and filter, based on the effective status.

## Directory

The directory is provided by another plugin, which registers it in an `after_plugins_loaded` hook:

```ruby
class MyPlugin::Hooks < Redmine::Hook::Listener
  def after_plugins_loaded(_context = {})
    RedmineInternalUsers.directory = MyDirectory.new if defined?(RedmineInternalUsers)
  end
end
```

A directory is any object responding to:

- `internal_mails(mails)`: the given mail addresses that belong to internal users, downcased. It must raise an error when the source cannot be queried, so that a failure is never mistaken for "not found".
- `internal_details(mails)` (optional): lines describing the matching entries, shown to administrators when they check a user.

```ruby
class MyDirectory
  def internal_mails(mails)
    staff = MyHrService.search(mails) # raises when the service is down
    staff.map { |person| person.mail.downcase } & mails.map(&:downcase)
  end

  def internal_details(mails)
    MyHrService.search(mails).map { |person| "#{person.login} | #{person.department}" }
  end
end
```

Without a registered directory, nobody is promoted: the check button is hidden and the rake task aborts.

## When the status is refreshed

- **At login**: only after an OIDC login (`openid_connect` provider), with the mail claim verified by the identity provider. The addresses of an account can be edited by its user, so they are never trusted at login. The verified address is kept in `users.internal_mail`. If the directory cannot be queried, the previous status is kept and the login goes on.
- **On request**: the "Check in the directory" button of the user form (administrators) shows the addresses looked up, those found, the details given by the directory, or the error, and refreshes the status.
- **By a rake task**. Initial run, once, to promote the existing accounts from their stored addresses:

  ```
  bundle exec rake redmine:internal_users:sync SEED=1 RAILS_ENV=production
  ```

  Regular run (cron), which only demotes internal users no longer in the directory:

  ```
  30 3 * * * cd /path/to/redmine && bundle exec rake redmine:internal_users:sync RAILS_ENV=production
  ```

  The task changes nothing if a directory query fails, or if more than 10% of the internal users would be demoted (run again with `FORCE=1` to confirm). The promoted and demoted logins are listed in `log/internal_users-<date>.log`.

Users are looked up by the address verified at their last OIDC login, or by the addresses of their account when never verified.

## Requirements

- [redmine_base_deface](https://github.com/jbbarth/redmine_base_deface)

## Installation

```
bundle exec rake redmine:plugins:migrate NAME=redmine_internal_users RAILS_ENV=production
```

## Tests

```
bundle exec rspec plugins/redmine_internal_users/spec
```
