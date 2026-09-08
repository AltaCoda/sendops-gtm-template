# SendOps Website Beacon — Google Tag Manager template

A Tag Manager custom template for [SendOps](https://sendops.dev) **Website
Identity**: it reads the first-party `so_vid` cookie your own server set, loads
`sendops.js`, and reports one `site_visit` per browser session so a Drip Workflow
can act when a customer you already know comes back to your site.

The template is `template.tpl` in this repository. Import it into your container,
or find *SendOps Website Beacon* in the Community Template Gallery once it is
listed there.

**Before this tag can do anything, your backend has to identify the visitor.**
The order is: call `POST /v1/contacts/identify` at login, set the returned id
as the `so_vid` cookie from your server, *then* install this tag. Nothing here
creates an identifier. The full walkthrough is at
[help.sendops.dev/website/installing-the-snippet](https://help.sendops.dev/website/installing-the-snippet)
and the API detail at
[developers.sendops.dev/api-reference/website-identity](https://developers.sendops.dev/api-reference/website-identity).

## Install

1. Tag Manager → **Templates** → **Tag Templates** → **New** → ⋮ → **Import**,
   and pick `template.tpl`.
2. Save it, then **Tags** → **New** → choose **SendOps Website Beacon**.
3. Fill in the **Site key** from SendOps → Workspace → Website (`pk_live_…`).
4. Trigger: **Initialization – All Pages**.

The tag reads the `so_vid` cookie, injects `https://api.sendops.dev/sendops.js`,
and calls `sendops.init` with the id it read. If the cookie is absent it does
nothing and loads nothing.

## Permissions the template declares

| Permission | Why |
|---|---|
| Reads cookie values — `so_vid` only | The visitor id your server set. |
| Injects scripts — `https://api.sendops.dev/sendops.js` only | The beacon itself. |
| Accesses globals — `sendops` | To call `sendops.init` once the script has loaded. |
| Logs to console — debug mode only | Nothing is logged in a live container. |

**Changing the cookie name** means editing the template's permissions: GTM's
`get_cookies` permission is a fixed allowlist and the template allows `so_vid`
only. Open the template → **Permissions** → *Reads cookie values* and add your
name, or the tag fails at runtime with a permission error rather than silently.

## Consent

The template declares the `analytics_storage` consent type, so a container with
Consent Mode configured holds the tag until that type is granted. In that setup
leave the **Wait for in-page consent** checkbox off — GTM is already the gate,
and turning both on means the beacon waits for a second signal that never
arrives. Turn the checkbox on only when a consent banner on the page calls
`sendops.consent(true)` itself.

## Custom events

Push to the data layer; no second tag is needed. `sendops.js` watches the data layer itself, so the template needs no data-layer permission for this:

```js
dataLayer.push({ event: 'sendops_track', name: 'site_pricing_viewed' })
dataLayer.push({
  event: 'sendops_track',
  name: 'site_demo_requested',
  properties: { plan: 'growth', seats: 12 },
})
```

Names must match `^site_[a-z0-9_]{1,60}$`; anything else is dropped and counted
under *bad name* on the beacon health card. Properties carry up to ten string,
number or boolean values of your own, alongside the page path, referrer, title
and UTM values the beacon adds itself.

## What it never does

It never assigns `document.cookie`, never touches `localStorage`, and never
generates an identifier. The id is minted by SendOps and set as an HTTP cookie
by your server, which is the only form Safari's Intelligent Tracking Prevention
leaves at its full lifetime. A tag that wrote the cookie from JavaScript would
cap it at seven days and quietly undo the whole design.

A visitor without the cookie is invisible: no request, no storage. An id SendOps
does not recognise is dropped at the edge with no record.

## Versions

`metadata.yaml` lists each published version by commit, as the Community
Template Gallery requires. The template is developed alongside the SendOps
backend and synced here; open an issue on this repository if the imported
template and the documented behaviour disagree.

## License

Apache 2.0 — see [LICENSE](LICENSE).
