# Platform Role Policy

Skyforge uses platform role profiles for lab scheduling, quick deploy access,
Forward tenant reset permissions, integration operations, and admin-only
surfaces.

## Default Profiles

- `viewer`: read-only curated catalog access.
- `demo-user`: constrained demo/read-only-style access.
- `lab-user`: default profile for normal OIDC users; can launch curated labs,
  reserve future capacity, and reset the user's own Forward tenant.
- `sandbox-user`: custom template launches and limited persistent lab state.
- `trainer`: curated/training profile with broader reservation quota.
- `integration-user`: integration and TestDrive operations without full admin.
- `admin`: full platform operation and user/role administration.

New users with no explicit profile resolve to `lab-user`. Direct admin grants
still add the `admin` profile.

## Admin Management

Admins with `manage_users_roles` can manage role behavior from Admin Settings:

- assign profiles and quota overrides for individual users
- edit role capability bundles, operating modes, default quota, and default role
- set role-level API allow/deny entries from the generated API catalog
- set per-user API allow/deny overrides for exceptions

API permission precedence is:

1. per-user explicit deny/allow
2. role-profile deny
3. role-profile allow
4. existing endpoint auth, admin tag, and platform capability checks

The `admin` role profile must retain `manage_users_roles` to prevent policy
lockout.
