# frozen_string_literal: true

require "spec_helper"

describe InternalStatusController, :type => :controller do
  render_views
  fixtures :users, :email_addresses

  let(:directory) { double("directory") }
  let(:user) { User.find(2) }

  around do |example|
    registered = RedmineInternalUsers.directory
    RedmineInternalUsers.directory = directory
    example.run
  ensure
    RedmineInternalUsers.directory = registered
  end

  before do
    @request.session[:user_id] = 1 # admin
  end

  def check
    post :check, :params => { :id => user.id }, :xhr => true
  end

  it "shows the result and the refreshed status" do
    allow(directory).to receive(:internal_mails).and_return(Set['jsmith@somenet.foo'])
    allow(directory).to receive(:internal_details).and_return(['uid=jsmith,ou=people,dc=example,dc=org'])

    check

    expect(response).to have_http_status(:success)
    expect(response.body).to include('jsmith@somenet.foo', 'uid=jsmith,ou=people,dc=example,dc=org', 'internal-status-info')
    expect(user.reload.internal).to be true
  end

  it "shows the error and changes nothing when the directory fails" do
    user.update_columns(internal: true)
    allow(directory).to receive(:internal_mails).and_raise(IOError, "connection failed: timeout")

    check

    expect(response).to have_http_status(:success)
    expect(response.body).to include('connection failed: timeout')
    expect(user.reload.internal).to be true
    expect(user.internal_checked_at).to be_nil
  end

  it "is reserved to administrators" do
    @request.session[:user_id] = 2
    expect(directory).not_to receive(:internal_mails)

    check

    expect(response).to have_http_status(:forbidden)
  end
end
