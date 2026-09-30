# frozen_string_literal: true

require "spec_helper"

describe "Internal users" do
  fixtures :users, :email_addresses

  let(:internal) { User.find(4).tap { |u| u.update_columns(internal: true) } }
  let(:external) { User.find(3) }

  describe "User#internal_user?" do
    it "uses the status computed from the directory by default" do
      expect(external.internal_user?).to be false
      expect(internal.internal_user?).to be true
    end

    it "prefers the status forced by an administrator" do
      internal.update_columns(internal_forced: false)
      expect(internal.internal_user?).to be false

      external.update_columns(internal_forced: true)
      expect(external.internal_user?).to be true
    end

    it "is false for anonymous and unsaved users" do
      expect(User.anonymous.internal_user?).to be false
      expect(User.new(internal: true).internal_user?).to be false
    end
  end

  describe "internal_forced" do
    it "is only settable by an administrator" do
      expect(external.safe_attribute?('internal_forced', User.find(1))).to be true
      expect(external.safe_attribute?('internal_forced', User.find(2))).to be false
    end
  end

  describe "user query" do
    it "filters users on the effective internal status" do
      internal
      external.update_columns(internal: true, internal_forced: false)
      query = UserQuery.new(name: '_')
      query.filters = { 'internal_user' => { operator: '=', values: ['1'] } }
      expect(query.results_scope.ids).to eq [4]
      query.filters = { 'internal_user' => { operator: '!', values: ['1'] } }
      expect(query.results_scope.ids).not_to include(4)
      expect(query.results_scope.ids).to include(3)
    end
  end
end
