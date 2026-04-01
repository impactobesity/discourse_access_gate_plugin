# discourse-access-gate

A Discourse plugin that gates new OIDC signups by checking Clerk's `publicMetadata` claims. Users who haven't completed onboarding in the mobile app are rejected at signup — no Discourse account is created.

Existing users can always log in freely. The gate only applies to new signups via OIDC.

## How it works

The plugin hooks into Discourse's `:after_auth` event, which fires after OIDC authentication but before any account is created. It inspects the `publicMetadata` from the Clerk OIDC response for a configurable key (default: `forum_onboarded`). If the key is missing or empty, the signup is rejected with a user-facing error message.

This follows the same pattern used by Discourse's Discord authenticator to restrict forum access to specific Discord guild members.

## Prerequisites

Clerk must be configured to include `publicMetadata` in the OIDC response:

1. In **Clerk Dashboard** → **JWT Templates** (or OIDC configuration), add `publicMetadata` to the ID token claims
2. In Discourse admin, ensure `openid_connect_authorize_scope` includes whatever scope Clerk requires
3. The mobile app must write the gating key (e.g., `forum_onboarded: "2026-04-01T00:00:00Z"`) to Clerk's `publicMetadata` via the Clerk Backend API after onboarding completes

### Verifying Clerk sends the claim

1. Enable `openid_connect_verbose_logging` in Discourse admin
2. Attempt an OIDC login
3. Check `/admin/logs` — search for "OIDC Log"
4. Confirm `publicMetadata` appears in the `raw_info` dump

## Site settings

| Setting | Default | Description |
|---------|---------|-------------|
| `access_gate_enabled` | `false` | Enable/disable the signup gate |
| `access_gate_metadata_key` | `forum_onboarded` | The key within `publicMetadata` that must be present |

## Installation

**Docker** (standard production): Add the plugin repo URL to `app.yml` under `hooks.after_code.exec.cmd` and rebuild:

```yaml
hooks:
  after_code:
    - exec:
        cd: $home/plugins
        cmd:
          - git clone https://github.com/impactobesity/discourse_access_gate_plugin.git
```

Then rebuild: `./launcher rebuild app`

**Development**: Clone into the `plugins/` directory and restart Discourse.

## License

MIT
