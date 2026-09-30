# frozen_string_literal: true

require "spec_helper"

describe InternalUserStatus do
  fixtures :users, :email_addresses

  let(:directory) { double("directory") }
  let(:user) { User.find(2) } # jsmith@somenet.foo
  let(:oidc_auth) { { 'provider' => 'openid_connect', 'info' => { 'email' => 'John.Smith@example.org' } } }

  around do |example|
    registered = RedmineInternalUsers.directory
    RedmineInternalUsers.directory = directory
    example.run
  ensure
    RedmineInternalUsers.directory = registered
  end

  def request_with(auth)
    double(env: auth ? { 'omniauth.auth' => auth } : {})
  end

  describe ".refresh_after_login" do
    it "promotes a user whose verified mail is in the directory" do
      allow(directory).to receive(:internal_mails).with(['john.smith@example.org']).and_return(Set['john.smith@example.org'])

      described_class.refresh_after_login(user, request_with(oidc_auth))

      expect(user.reload.internal).to be true
      expect(user.internal_mail).to eq 'john.smith@example.org'
      expect(user.internal_checked_at).to be_present
    end

    it "demotes a user whose verified mail is not in the directory" do
      user.update_columns(internal: true)
      allow(directory).to receive(:internal_mails).and_return(Set.new)

      described_class.refresh_after_login(user, request_with(oidc_auth))

      expect(user.reload.internal).to be false
    end

    it "keeps the previous status and the login when the directory fails" do
      user.update_columns(internal: true)
      allow(directory).to receive(:internal_mails).and_raise(IOError, "down")

      expect { described_class.refresh_after_login(user, request_with(oidc_auth)) }.not_to raise_error
      expect(user.reload.internal).to be true
      expect(user.internal_checked_at).to be_nil
    end

    it "does not touch a status forced by an administrator" do
      user.update_columns(internal_forced: false)
      expect(directory).not_to receive(:internal_mails)

      described_class.refresh_after_login(user, request_with(oidc_auth))
    end

    it "ignores logins without a verified OIDC mail" do
      expect(directory).not_to receive(:internal_mails)

      described_class.refresh_after_login(user, request_with(nil))
      described_class.refresh_after_login(user, request_with(oidc_auth.merge('provider' => 'cas')))
      described_class.refresh_after_login(user, request_with(oidc_auth.merge('info' => {})))
    end

    it "does nothing without a registered directory" do
      RedmineInternalUsers.directory = nil

      described_class.refresh_after_login(user, request_with(oidc_auth))

      expect(user.reload.internal_checked_at).to be_nil
    end
  end

  describe ".check!" do
    it "returns the addresses found and the details given by the directory" do
      allow(directory).to receive(:internal_mails).and_return(Set['jsmith@somenet.foo'])
      allow(directory).to receive(:internal_details).and_return(['uid=jsmith,ou=people,dc=example,dc=org'])

      result = described_class.check!(user)

      expect(result).to eq(mails: ['jsmith@somenet.foo'], found: Set['jsmith@somenet.foo'], details: ['uid=jsmith,ou=people,dc=example,dc=org'], changed: true)
      expect(user.reload.internal).to be true
    end

    it "tells when the status did not change" do
      user.update_columns(internal: true)
      allow(directory).to receive(:internal_mails).and_return(Set['jsmith@somenet.foo'])

      expect(described_class.check!(user)[:changed]).to be false
    end

    it "works with a directory giving no details" do
      allow(directory).to receive(:internal_mails).and_return(Set.new)

      expect(described_class.check!(user)[:details]).to eq []
    end

    it "looks up the address verified at login rather than the addresses of the account" do
      user.update_columns(internal_mail: 'john.smith@example.org')
      expect(directory).to receive(:internal_mails).with(['john.smith@example.org']).and_return(Set.new)

      described_class.check!(user)
    end

    it "does not change a forced status" do
      user.update_columns(internal_forced: false)
      allow(directory).to receive(:internal_mails).and_return(Set['jsmith@somenet.foo'])

      described_class.check!(user)

      expect(user.reload.internal).to be false
      expect(user.internal_checked_at).to be_nil
    end

    it "raises a DirectoryError when the directory fails" do
      allow(directory).to receive(:internal_mails).and_raise(IOError, "unreachable")

      expect { described_class.check!(user) }.to raise_error(RedmineInternalUsers::DirectoryError, "unreachable")
    end
  end
end
