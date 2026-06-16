# Synclock Site

Static landing page for [synclock.caiano.com](https://synclock.caiano.com), following
the same Cloudflare Workers static-assets pattern as Lineup.

No build step is required.

## Deploy

Use the Caiano Cloudflare account, not GAM3S.

```sh
cd site
npx wrangler deploy
```

The Worker name is `synclock` (`wrangler.toml`). Attach
`synclock.caiano.com` as the route/custom domain in Cloudflare.
