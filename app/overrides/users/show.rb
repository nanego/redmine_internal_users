# frozen_string_literal: true

Deface::Override.new :virtual_path => 'users/show',
                     :name => 'add-internal-badge-to-user-name',
                     :insert_bottom => 'h2',
                     :text => "<%= render :partial => 'internal_users/internal_badge', :locals => { :user => @user } %>"
