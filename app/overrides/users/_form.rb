# frozen_string_literal: true

# Not rendered through the view_users_form hook: another plugin may close the
# "Information" fieldset in its own hook output
Deface::Override.new :virtual_path => 'users/_form',
                     :name => 'add-internal-status-to-users-form',
                     # Applied after the other insertions: ends the fieldset
                     :sequence => 200,
                     :insert_before => "erb[loud]:contains('call_hook(:view_users_form, :user => @user, :form => f)')",
                     :text => "<%= render :partial => 'internal_users/users_form', :locals => { :user => @user, :form => f } %>"
