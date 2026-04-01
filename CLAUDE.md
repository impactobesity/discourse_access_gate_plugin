# discourse-access-gate

Discourse plugin that gates new OIDC signups by checking Clerk `publicMetadata` claims.

## Architecture

- **No routes, controllers, engine, or frontend assets.** The entire plugin is a single `:after_auth` event hook in `plugin.rb`.
- Hooks into Discourse's auth flow via `DiscourseEvent.trigger(:after_auth)`, which fires after OIDC authentication but before account creation.
- Reads the raw OmniAuth hash from `request.env["omniauth.auth"]` — not from `auth_result.extra_data`, which only contains `{ provider:, uid: }`.
- Sets `auth_result.failed = true` to reject unauthorized signups. This short-circuits the flow so no user record is created.

## Key files

- `plugin.rb` — all plugin logic (event hook, claim checking)
- `config/settings.yml` — site settings (`access_gate_enabled`, `access_gate_metadata_key`)
- `config/locales/server.en.yml` — setting descriptions and rejection message
- `config/locales/client.en.yml` — admin UI settings category name
- `spec/plugin_spec.rb` — unit tests for auth gating logic

## Testing

Tests run via Discourse's standard CI workflow (`.github/workflows/discourse-plugin.yml`). Specs trigger the `:after_auth` event directly with mock objects and assert on the `auth_result` state.

To run locally inside a Discourse dev environment:
```
bin/rake plugin:spec[discourse-access-gate]
```

## Conventions

- Plugin follows the Discord guild-gating pattern from Discourse core (`lib/auth/discord_authenticator.rb`)
- Checks both `publicMetadata` (camelCase) and `public_metadata` (snake_case) key variants to handle middleware normalization
- Checks both string and symbol keys for the same reason
