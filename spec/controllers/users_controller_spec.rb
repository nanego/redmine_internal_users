# frozen_string_literal: true

require "spec_helper"

describe UsersController, :type => :controller do
  render_views
  fixtures :users, :email_addresses, :user_preferences

  before do
    @request.session[:user_id] = 1 # admin
  end

  it "adds the internal status to the information of the user form" do
    get :edit, :params => { :id => 2 }

    expect(response).to have_http_status(:success)
    assert_select 'fieldset.box.tabular select#user_internal_forced'
  end
end
