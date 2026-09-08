# SendOps Website Beacon — Google Tag Manager template

A Tag Manager custom template for [SendOps](https://sendops.dev) **Website
Identity**: it reads the first-party `so_vid` cookie your own server set, loads
`sendops.js`, and reports website activity so a Drip Workflow can act when a
customer you already know comes back to your site.

One template, two tag types:

| Tag type | What it does | Trigger it on |
|---|---|---|
| **Page visit** (default) | Loads the beacon and sends one `site_visit` per browser session. | Initialization – All Pages |
| **Track event** | Fires a custom `site_*` event, with optional properties, and no page code at all. | Whatever you like |

Track event is what turns an ordinary GTM trigger into a SendOps activity. A
Page visit tag has to be installed either way: it is the tag that starts the
beacon.

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
3. Leave **Tag type** on **Page visit**.
4. Fill in the **Site key** from SendOps → Workspace → Website (`pk_live_…`).
5. Trigger: **Initialization – All Pages**.

The tag reads the `so_vid` cookie, injects `https://api.sendops.dev/sendops.js`,
and calls `sendops.init` with the id it read. If the cookie is absent it does
nothing and loads nothing.

Upgrading from an earlier version changes nothing about a tag you already have.
Tags saved before Track event existed carry no tag type at all, and the template
reads a missing value as Page visit.

## Permissions the template declares

| Permission | Why |
|---|---|
| Reads cookie values — `so_vid` only | The visitor id your server set. |
| Injects scripts — `https://api.sendops.dev/sendops.js` only | The beacon itself. |
| Accesses globals — `sendops`, `sendops.init`, `sendops.track` | To call `sendops.init` (Page visit) or `sendops.track` (Track event) once the script has loaded. |
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

### From a GTM trigger, with no page code

Add a second tag, set **Tag type** to **Track event**, and give it a name. A
worked example — "someone looked at pricing":

1. **Triggers** → **New** → *Page View*, firing on *Some Page Views* with the
   condition **Page Path** *contains* `/pricing`.
2. **Tags** → **New** → **SendOps Website Beacon**, **Tag type** = *Track
   event*, **Event name** = `site_pricing_viewed`, same **Site key**. Attach the
   trigger.
3. In SendOps, a workflow can now start with
   `enter on activity.site_pricing_viewed`.

**Event properties** is an optional name/value table, and GTM variables work in
the value column, so `plan` = `{{DLV - plan}}` sends whatever the data layer
holds. A row whose value is unset is left out of the event entirely rather than
sent as the string `undefined`; an empty string is a real value and is kept.

Property names must match `^[a-z][a-z0-9_]{0,31}$`. The tag drops the rest
before sending and says which in a debug-mode console message. SendOps keeps at
most ten properties of your own per event and silently drops any beyond that,
so list the ones you will filter on first.

### Filtering on a property in a workflow

Every `site_*` event carries `path`, `referrer`, `title`, `utm_source`,
`utm_medium` and `utm_campaign` without you listing them, and those six are
filterable with no setup:

```
enter on activity.site_pricing_viewed
  where exists(activity.site_pricing_viewed where path starts with "/pricing")
```

A property of your own has to be **promoted** first, through
`POST /v1/activity-properties` or the audience schema file in a connected
repository. Once promoted it filters the same way:

```
enter on activity.site_pricing_viewed
  where exists(activity.site_pricing_viewed where plan = "growth")
```

A trigger's `where` is a full contact predicate, not a filter on the event that
fired, which is why the property test sits inside `exists(...)`. Strings compare
with `=` and double quotes.

The Track event tag does not call `sendops.init`, so a Page visit tag still has
to be installed on your pages. Order between the two does not matter: the
snippet queues up to ten `track` calls made before `init` and replays them, and
it mints the event id itself.

Like Page visit, a Track event tag with no `so_vid` cookie sends nothing and
loads nothing.

### From your own page code

Push to the data layer instead when the event is raised by code you already
write. `sendops.js` watches the data layer itself, so no second tag is needed
and the template needs no data-layer permission:

```js
dataLayer.push({ event: 'sendops_track', name: 'site_pricing_viewed' })
dataLayer.push({
  event: 'sendops_track',
  name: 'site_demo_requested',
  properties: { plan: 'growth', seats: 12 },
})
```

### Either way

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
