# frozen_string_literal: true

require "rails_helper"

describe "AccessGatePlugin" do
  let(:authenticator) { OpenStruct.new(name: "oidc") }
  let(:non_oidc_authenticator) { OpenStruct.new(name: "google_oauth2") }
  let(:session) { {} }
  let(:cookies) { {} }
  let(:metadata_key) { "forum_onboarded" }

  def build_auth_result(user: nil, failed: false)
    Auth::Result.new.tap do |result|
      result.user = user
      result.failed = failed
    end
  end

  def build_request(raw_info: {})
    env = { "omniauth.auth" => { extra: { raw_info: raw_info } } }
    OpenStruct.new(env: env)
  end

  before do
    SiteSetting.access_gate_enabled = true
    SiteSetting.access_gate_metadata_key = metadata_key
  end

  context "when plugin is disabled" do
    before { SiteSetting.access_gate_enabled = false }

    it "does not interfere with authentication" do
      auth_result = build_auth_result
      request = build_request(raw_info: {})

      DiscourseEvent.trigger(:after_auth, authenticator, auth_result, session, cookies, request)

      expect(auth_result.failed).to be_falsey
    end
  end

  context "when authenticator is not OIDC" do
    it "does not interfere with authentication" do
      auth_result = build_auth_result
      request = build_request(raw_info: {})

      DiscourseEvent.trigger(:after_auth, non_oidc_authenticator, auth_result, session, cookies, request)

      expect(auth_result.failed).to be_falsey
    end
  end

  context "when auth has already failed" do
    it "does not overwrite the existing failure" do
      auth_result = build_auth_result(failed: true)
      auth_result.failed_reason = "Some other reason"
      request = build_request(raw_info: {})

      DiscourseEvent.trigger(:after_auth, authenticator, auth_result, session, cookies, request)

      expect(auth_result.failed_reason).to eq("Some other reason")
    end
  end

  context "when user already exists" do
    it "allows login without checking claims" do
      user = Fabricate(:user)
      auth_result = build_auth_result(user: user)
      request = build_request(raw_info: {})

      DiscourseEvent.trigger(:after_auth, authenticator, auth_result, session, cookies, request)

      expect(auth_result.failed).to be_falsey
    end
  end

  context "when new user has the required claim (camelCase)" do
    it "allows signup" do
      auth_result = build_auth_result
      request = build_request(raw_info: { "publicMetadata" => { metadata_key => "2026-04-01T00:00:00Z" } })

      DiscourseEvent.trigger(:after_auth, authenticator, auth_result, session, cookies, request)

      expect(auth_result.failed).to be_falsey
    end
  end

  context "when new user has the required claim (snake_case)" do
    it "allows signup" do
      auth_result = build_auth_result
      request = build_request(raw_info: { "public_metadata" => { metadata_key => "2026-04-01T00:00:00Z" } })

      DiscourseEvent.trigger(:after_auth, authenticator, auth_result, session, cookies, request)

      expect(auth_result.failed).to be_falsey
    end
  end

  context "when new user has the required claim (symbol keys)" do
    it "allows signup" do
      auth_result = build_auth_result
      request = build_request(raw_info: { publicMetadata: { metadata_key.to_sym => "2026-04-01T00:00:00Z" } })

      DiscourseEvent.trigger(:after_auth, authenticator, auth_result, session, cookies, request)

      expect(auth_result.failed).to be_falsey
    end
  end

  context "when new user is missing the required claim" do
    it "rejects signup" do
      auth_result = build_auth_result
      request = build_request(raw_info: { "publicMetadata" => {} })

      DiscourseEvent.trigger(:after_auth, authenticator, auth_result, session, cookies, request)

      expect(auth_result.failed).to eq(true)
      expect(auth_result.failed_reason).to include("not yet authorized")
    end
  end

  context "when publicMetadata is absent entirely" do
    it "rejects signup" do
      auth_result = build_auth_result
      request = build_request(raw_info: {})

      DiscourseEvent.trigger(:after_auth, authenticator, auth_result, session, cookies, request)

      expect(auth_result.failed).to eq(true)
    end
  end

  context "when omniauth.auth is missing from request" do
    it "rejects signup" do
      auth_result = build_auth_result
      request = OpenStruct.new(env: {})

      DiscourseEvent.trigger(:after_auth, authenticator, auth_result, session, cookies, request)

      expect(auth_result.failed).to eq(true)
    end
  end

  context "with a custom metadata key" do
    before { SiteSetting.access_gate_metadata_key = "app_verified" }

    it "checks the custom key" do
      auth_result = build_auth_result
      request = build_request(raw_info: { "publicMetadata" => { "app_verified" => "yes" } })

      DiscourseEvent.trigger(:after_auth, authenticator, auth_result, session, cookies, request)

      expect(auth_result.failed).to be_falsey
    end

    it "rejects when custom key is missing" do
      auth_result = build_auth_result
      request = build_request(raw_info: { "publicMetadata" => { "forum_onboarded" => "2026-04-01" } })

      DiscourseEvent.trigger(:after_auth, authenticator, auth_result, session, cookies, request)

      expect(auth_result.failed).to eq(true)
    end
  end
end
