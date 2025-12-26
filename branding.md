# Branding assets

Skyforge UI branding is driven by environment variables and a small set of assets.

## 1) Config values
Set these in `k8s/overlays/k3s-traefik-secrets/config.env` (or the `skyforge-config` ConfigMap):
- `SKYFORGE_UI_PRODUCT_NAME`
- `SKYFORGE_UI_PRODUCT_SUBTITLE`
- `SKYFORGE_UI_LOGO_URL`
- `SKYFORGE_UI_LOGO_ALT`
- `SKYFORGE_UI_HEADER_BG_URL`
- `SKYFORGE_UI_SUPPORT_TEXT`
- `SKYFORGE_UI_SUPPORT_URL`

## 2) Default assets (safe to replace)
- `portal/public/assets/skyforge/skyforge-mark.svg` (product mark)
- `portal/public/assets/skyforge/header-background.png` (header image)
- `portal/public/assets/skyforge/FN-logo.svg` (optional alternate logo)
- `server/static/brand/logo.svg` (legacy brand asset for server-side pages)
- `server/static/brand/skyforge.css` (brand styling)

If you replace assets, keep filenames the same or update the corresponding config values.
