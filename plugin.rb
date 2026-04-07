# frozen_string_literal: true

# name: discourse-access-gate
# about: Rejects OIDC signups unless the user has completed onboarding in the mobile app
# version: 0.1.0
# authors: Impact Obesity
# url: https://github.com/impactobesity/discourse_access_gate_plugin
# required_version: 2.7.0

enabled_site_setting :access_gate_enabled

module ::AccessGatePlugin
  PLUGIN_NAME = "discourse-access-gate"
end

after_initialize do
  # Override the auth failure handler to redirect to a custom URL
  # when this plugin rejects a signup. Uses prepend (not add_to_class)
  # so that `super` preserves default Discourse behavior for all
  # other auth failures, even if the plugin is disabled.
  module ::AccessGatePlugin::OmniauthCallbacksOverride
    def render_auth_result_failure
      if SiteSetting.access_gate_enabled &&
           @auth_result.failed_code == "access_gate_rejected" &&
           SiteSetting.access_gate_redirect_url.present?
        redirect_to SiteSetting.access_gate_redirect_url, allow_other_host: true
      else
        super
      end
    end
  end

  Users::OmniauthCallbacksController.prepend(
    ::AccessGatePlugin::OmniauthCallbacksOverride,
  )

  on(:after_auth) do |authenticator, auth_result, session, cookies, request|
    next unless SiteSetting.access_gate_enabled

    # Only apply to OIDC authentication
    next if authenticator.name != "oidc"

    # Don't interfere with already-failed auth attempts
    next if auth_result.failed?

    # Let existing users log in freely — only gate new signups
    next if auth_result.user.present?

    # auth_result.extra_data only has { provider:, uid: }, NOT the full claims.
    # The raw OmniAuth hash is still on the request at this point.
    auth_token = request.env["omniauth.auth"]

    raw_info = auth_token&.dig(:extra, :raw_info) || auth_token&.dig("extra", "raw_info") || {}
    metadata_key = SiteSetting.access_gate_metadata_key

    # Check both camelCase and snake_case variants defensively,
    # since middleware layers may normalize key casing
    value =
      raw_info.dig("publicMetadata", metadata_key) ||
        raw_info.dig(:publicMetadata, metadata_key.to_sym) ||
        raw_info.dig("public_metadata", metadata_key) ||
        raw_info.dig(:public_metadata, metadata_key.to_sym)

    if value.blank?
      auth_result.failed = true
      auth_result.failed_code = "access_gate_rejected"
      auth_result.failed_reason = I18n.t("access_gate.signup_rejected")
    end
  end
end
