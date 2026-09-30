# frozen_string_literal: true

require_dependency 'query'
require_dependency 'user_query'

module RedmineInternalUsers
  module UserQueryPatch
    INTERNAL_USER_SQL = "COALESCE(#{User.table_name}.internal_forced, #{User.table_name}.internal)"

    def initialize_available_filters
      super
      add_available_filter("internal_user",
                           :type => :list,
                           :values => [[l(:general_text_yes), "1"], [l(:general_text_no), "0"]])
    end

    def sql_for_internal_user_field(_field, operator, value)
      internal = value.first.to_s == '1'
      internal = !internal if operator == '!'
      "#{INTERNAL_USER_SQL} = #{internal ? self.class.connection.quoted_true : self.class.connection.quoted_false}"
    end
  end
end

UserQuery.prepend RedmineInternalUsers::UserQueryPatch

unless UserQuery.available_columns.any? { |c| c.name == :internal_user }
  UserQuery.available_columns << QueryColumn.new(:internal_user, :sortable => RedmineInternalUsers::UserQueryPatch::INTERNAL_USER_SQL)
end
