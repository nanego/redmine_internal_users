# frozen_string_literal: true

require 'spec_helper'

describe InternalUserSync do
  fixtures :users, :email_addresses

  let(:directory) { double("directory") }
  let(:internal) { User.find(2) }    # jsmith@somenet.foo
  let(:external) { User.find(3) } # dlopper@somenet.foo

  def directory_knows(*users)
    allow(directory).to receive(:internal_mails).and_return(users.map { |user| user.mail.downcase }.to_set)
  end

  it "only demotes by default" do
    external.update_columns(internal: true)
    directory_knows(internal)

    sync = described_class.new(directory: directory, force: true).run

    expect(sync.promoted).to be_empty
    expect(sync.demoted).to eq [external.id]
    expect(internal.reload.internal).to be false
    expect(external.reload.internal).to be false
  end

  it "promotes the users found in the directory when seeding" do
    directory_knows(internal)

    sync = described_class.new(directory: directory, seed: true).run

    expect(sync.promoted).to eq [internal.id]
    expect(internal.reload.internal).to be true
    expect(internal.internal_checked_at).to be_present
    expect(external.reload.internal).to be false
  end

  it "looks up the address verified at login rather than the addresses of the account" do
    external.update_columns(internal: true, internal_mail: 'dlopper@example.org')
    internal.update_columns(internal: true)
    allow(directory).to receive(:internal_mails).and_return(Set['dlopper@example.org', internal.mail.downcase])

    described_class.new(directory: directory).run

    expect(directory).to have_received(:internal_mails).with(contain_exactly('dlopper@example.org', internal.mail.downcase))
    expect(external.reload.internal).to be true
  end

  it "leaves the statuses forced by an administrator untouched" do
    external.update_columns(internal: true, internal_forced: true)
    directory_knows

    described_class.new(directory: directory, force: true).run

    expect(external.reload.internal).to be true
  end

  it "aborts without writing anything when too many users would be demoted" do
    internal.update_columns(internal: true)
    external.update_columns(internal: true)
    directory_knows

    expect { described_class.new(directory: directory).run }.to raise_error(InternalUserSync::TooManyDemotions)
    expect(User.where(internal: true).ids).to contain_exactly(internal.id, external.id)
  end

  it "aborts without writing anything when the directory fails" do
    internal.update_columns(internal: true)
    allow(directory).to receive(:internal_mails).and_raise(IOError, "down")

    expect { described_class.new(directory: directory, force: true).run }.to raise_error(RedmineInternalUsers::DirectoryError)
    expect(internal.reload.internal).to be true
  end
  it "aborts without writing anything when no directory is registered" do
    internal.update_columns(internal: true)

    expect { described_class.new(directory: nil, force: true).run }.to raise_error(RedmineInternalUsers::DirectoryError)
    expect(internal.reload.internal).to be true
  end
end
