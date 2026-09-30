# frozen_string_literal: true

require 'redmine'
require_relative 'lib/redmine_internal_users'
require_relative 'lib/redmine_internal_users/hooks'

Rails.autoloaders.main.ignore("#{__dir__}/lib")

Redmine::Plugin.register :redmine_internal_users do
  name 'Redmine Internal Users plugin'
  description 'Tells internal users from external ones, according to a directory'
  author 'Vincent ROBERT'
  url 'https://github.com/nanego/redmine_internal_users'
  version '1.0.0'
  requires_redmine :version_or_higher => '6.1.0'
  requires_redmine_plugin :redmine_base_rspec, :version_or_higher => '0.0.3' if Rails.env.test?
  requires_redmine_plugin :redmine_base_deface, :version_or_higher => '0.0.1'
end
