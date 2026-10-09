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

  describe "internal badge on the user profile" do
    it "is shown to administrators for an internal user" do
      User.find(2).update_columns(internal: true)

      get :show, :params => { :id => 2 }

      expect(response).to have_http_status(:success)
      assert_select 'h2 span.badge-internal'
    end

    it "is not shown for an external user" do
      User.find(2).update_columns(internal: true, internal_forced: false)

      get :show, :params => { :id => 2 }

      assert_select 'h2 span.badge-internal', 0
    end

    it "is not shown to non-administrators" do
      User.find(2).update_columns(internal: true)
      @request.session[:user_id] = 3

      get :show, :params => { :id => 2 }

      expect(response).to have_http_status(:success)
      assert_select 'h2 span.badge-internal', 0
    end
  end
end
