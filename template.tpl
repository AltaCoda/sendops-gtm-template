___TERMS_OF_SERVICE___

By creating or modifying this file you agree to Google Tag Manager's Community
Template Gallery Developer Terms of Service available at
https://developers.google.com/tag-manager/gallery-tos (or such other URL as
Google may provide), as modified from time to time.


___INFO___

{
  "type": "TAG",
  "id": "cvt_temp_public_id",
  "version": 1,
  "securityGroups": [],
  "displayName": "SendOps Website Beacon",
  "categories": [
    "ANALYTICS",
    "MARKETING",
    "PERSONALIZATION"
  ],
  "brand": {
    "id": "brand_dummy",
    "displayName": "SendOps"
  },
  "description": "Reports website activity to SendOps for a visitor your own server already identified. Page visit sends one site_visit per browser session; Track event turns any GTM trigger into a custom site_* event with no page code. The tag only reads the first-party so_vid cookie your server set; it never writes a cookie and never generates an identifier, so Safari's 7-day cap on script-written cookies does not apply.",
  "containerContexts": [
    "WEB"
  ],
  "consentSettings": {
    "consentStatus": "NEEDED",
    "consentTypes": [
      {
        "consentType": "analytics_storage",
        "comment": "The beacon stores one sessionStorage key so it sends a single visit per session."
      }
    ]
  }
}


___TEMPLATE_PARAMETERS___

[
  {
    "type": "SELECT",
    "name": "tagType",
    "displayName": "Tag type",
    "simpleValueType": true,
    "defaultValue": "page_visit",
    "selectItems": [
      {
        "value": "page_visit",
        "displayValue": "Page visit — one per session"
      },
      {
        "value": "track_event",
        "displayValue": "Track event — fire a custom site_* event"
      }
    ],
    "help": "Page visit is the tag you install once on Initialization – All Pages; it loads the beacon and sends one site_visit per browser session. Track event fires a custom site_* event on whatever trigger you attach it to. A Page visit tag must be installed on your pages either way — it is what starts the beacon."
  },
  {
    "type": "TEXT",
    "name": "siteKey",
    "displayName": "Site key",
    "simpleValueType": true,
    "help": "The publishable site key from SendOps → Settings → Website. Starts with pk_live_. Used by the Page visit type; keep it filled in on every tag.",
    "valueValidators": [
      {
        "type": "NON_EMPTY"
      }
    ]
  },
  {
    "type": "TEXT",
    "name": "cookieName",
    "displayName": "Cookie name",
    "simpleValueType": true,
    "defaultValue": "so_vid",
    "help": "The first-party cookie your server sets with the SendOps visitor id. Leave as so_vid unless you renamed it.",
    "valueValidators": [
      {
        "type": "NON_EMPTY"
      }
    ]
  },
  {
    "type": "TEXT",
    "name": "eventName",
    "displayName": "Event name",
    "simpleValueType": true,
    "enablingConditions": [
      {
        "paramName": "tagType",
        "paramValue": "track_event",
        "type": "EQUALS"
      }
    ],
    "help": "Must start with site_ and match ^site_[a-z0-9_]{1,60}$ — for example site_pricing_viewed. This exact name is what a Drip Workflow references in \"enter on activity.site_pricing_viewed\", so pick it once and keep it stable. Anything else is dropped at the edge.",
    "valueValidators": [
      {
        "type": "NON_EMPTY"
      },
      {
        "type": "REGEX",
        "args": [
          "^site_[a-z0-9_]{1,60}$"
        ]
      }
    ]
  },
  {
    "type": "SIMPLE_TABLE",
    "name": "eventProperties",
    "displayName": "Event properties",
    "enablingConditions": [
      {
        "paramName": "tagType",
        "paramValue": "track_event",
        "type": "EQUALS"
      }
    ],
    "help": "Optional. Property names must match ^[a-z][a-z0-9_]{0,31}$ — lower-case, starting with a letter — and anything else is dropped before the event is sent. SendOps keeps at most 10 properties of your own per event and silently drops the rest, so put the ones you will filter on first. Values are sent as strings and GTM variables work in the value column. Every site_* event already carries path, referrer, title, utm_source, utm_medium and utm_campaign without you listing them, and those six are filterable straight away. A property of your own has to be promoted first, through POST /v1/activity-properties or the audience schema file in a connected repository, before a workflow can filter on it.",
    "simpleTableColumns": [
      {
        "defaultValue": "",
        "displayName": "Name",
        "name": "name",
        "type": "TEXT",
        "isUnique": true,
        "valueValidators": [
          {
            "type": "NON_EMPTY"
          }
        ]
      },
      {
        "defaultValue": "",
        "displayName": "Value",
        "name": "value",
        "type": "TEXT"
      }
    ]
  },
  {
    "type": "CHECKBOX",
    "name": "requireConsent",
    "checkboxText": "Wait for in-page consent before sending",
    "simpleValueType": true,
    "defaultValue": false,
    "enablingConditions": [
      {
        "paramName": "tagType",
        "paramValue": "page_visit",
        "type": "EQUALS"
      }
    ],
    "help": "Leave off if you gate this tag with Consent Mode or a GTM trigger. Turn on only when a consent banner on the page calls sendops.consent(true) itself."
  }
]


___SANDBOXED_JS_FOR_WEB_TEMPLATE___

const getCookieValues = require('getCookieValues');
const injectScript = require('injectScript');
const callInWindow = require('callInWindow');
const makeString = require('makeString');
const log = require('logToConsole');

const SNIPPET_URL = 'https://api.sendops.dev/sendops.js';

// Tags saved before Track Event mode existed carry no tagType at all. Missing
// or empty has to keep meaning Page visit, or every existing install changes
// behaviour on upgrade.
const tagType = data.tagType || 'page_visit';

const LOWER = 'abcdefghijklmnopqrstuvwxyz';
const KEY_CHARS = 'abcdefghijklmnopqrstuvwxyz0123456789_';

// SendOps accepts ^[a-z][a-z0-9_]{0,31}$ for a custom property key. The GTM
// sandbox has no regular expressions, so scan the characters instead.
const isValidPropertyKey = (key) => {
  if (typeof key !== 'string') return false;
  if (key.length < 1 || key.length > 32) return false;
  if (LOWER.indexOf(key.charAt(0)) === -1) return false;
  for (let i = 1; i < key.length; i++) {
    if (KEY_CHARS.indexOf(key.charAt(i)) === -1) return false;
  }
  return true;
};

const buildProperties = (rows) => {
  const properties = {};
  if (!rows) return properties;
  for (let i = 0; i < rows.length; i++) {
    const row = rows[i];
    if (!row) continue;
    const key = row.name;
    if (!isValidPropertyKey(key)) {
      log('SendOps Website Beacon: dropped property "' + makeString(key) +
          '" - names must match ^[a-z][a-z0-9_]{0,31}$');
      continue;
    }
    // An unset GTM variable arrives as undefined; sending the string
    // "undefined" would be worse than not sending the property at all. An
    // empty string is a real value and is kept.
    const value = row.value;
    if (value === undefined || value === null) {
      log('SendOps Website Beacon: dropped property "' + key + '" - no value');
      continue;
    }
    properties[key] = makeString(value);
  }
  return properties;
};

const cookieName = data.cookieName || 'so_vid';
const values = getCookieValues(cookieName);
const visitorId = values && values.length ? values[0] : '';

const onFailure = () => {
  log('SendOps Website Beacon: could not load ' + SNIPPET_URL);
  data.gtmOnFailure();
};

// No identified visitor means nothing to report. Skip the download entirely
// rather than loading a script that would decide to do nothing. Same for both
// tag types.
if (!visitorId) {
  data.gtmOnSuccess();
} else if (tagType === 'track_event') {
  const properties = buildProperties(data.eventProperties);

  const onTrack = () => {
    // Never init from here: the Page visit tag owns that. sendops.js queues
    // track calls made before init and replays them, so tag order is free.
    callInWindow('sendops.track', data.eventName, properties);
    data.gtmOnSuccess();
  };

  // Same URL and same cache token as the Page visit branch, so GTM injects the
  // snippet at most once per page however many tags ask for it.
  injectScript(SNIPPET_URL, onTrack, onFailure, SNIPPET_URL);
} else {
  const onSuccess = () => {
    callInWindow('sendops.init', {
      siteKey: data.siteKey,
      cookieName: cookieName,
      visitorId: visitorId,
      requireConsent: data.requireConsent === true
    });
    data.gtmOnSuccess();
  };

  injectScript(SNIPPET_URL, onSuccess, onFailure, SNIPPET_URL);
}


___WEB_PERMISSIONS___

[
  {
    "instance": {
      "key": {
        "publicId": "get_cookies",
        "versionId": "1"
      },
      "param": [
        {
          "key": "cookieAccess",
          "value": {
            "type": 1,
            "string": "specific"
          }
        },
        {
          "key": "cookieNames",
          "value": {
            "type": 2,
            "listItem": [
              {
                "type": 1,
                "string": "so_vid"
              }
            ]
          }
        }
      ]
    },
    "clientAnnotations": {
      "isEditedByUser": true
    },
    "isRequired": true
  },
  {
    "instance": {
      "key": {
        "publicId": "inject_script",
        "versionId": "1"
      },
      "param": [
        {
          "key": "urls",
          "value": {
            "type": 2,
            "listItem": [
              {
                "type": 1,
                "string": "https://api.sendops.dev/sendops.js"
              }
            ]
          }
        }
      ]
    },
    "clientAnnotations": {
      "isEditedByUser": true
    },
    "isRequired": true
  },
  {
    "instance": {
      "key": {
        "publicId": "access_globals",
        "versionId": "1"
      },
      "param": [
        {
          "key": "keys",
          "value": {
            "type": 2,
            "listItem": [
              {
                "type": 3,
                "mapKey": [
                  {
                    "type": 1,
                    "string": "key"
                  },
                  {
                    "type": 1,
                    "string": "read"
                  },
                  {
                    "type": 1,
                    "string": "write"
                  },
                  {
                    "type": 1,
                    "string": "execute"
                  }
                ],
                "mapValue": [
                  {
                    "type": 1,
                    "string": "sendops"
                  },
                  {
                    "type": 8,
                    "boolean": true
                  },
                  {
                    "type": 8,
                    "boolean": false
                  },
                  {
                    "type": 8,
                    "boolean": false
                  }
                ]
              },
              {
                "type": 3,
                "mapKey": [
                  {
                    "type": 1,
                    "string": "key"
                  },
                  {
                    "type": 1,
                    "string": "read"
                  },
                  {
                    "type": 1,
                    "string": "write"
                  },
                  {
                    "type": 1,
                    "string": "execute"
                  }
                ],
                "mapValue": [
                  {
                    "type": 1,
                    "string": "sendops.init"
                  },
                  {
                    "type": 8,
                    "boolean": true
                  },
                  {
                    "type": 8,
                    "boolean": false
                  },
                  {
                    "type": 8,
                    "boolean": true
                  }
                ]
              },
              {
                "type": 3,
                "mapKey": [
                  {
                    "type": 1,
                    "string": "key"
                  },
                  {
                    "type": 1,
                    "string": "read"
                  },
                  {
                    "type": 1,
                    "string": "write"
                  },
                  {
                    "type": 1,
                    "string": "execute"
                  }
                ],
                "mapValue": [
                  {
                    "type": 1,
                    "string": "sendops.track"
                  },
                  {
                    "type": 8,
                    "boolean": true
                  },
                  {
                    "type": 8,
                    "boolean": false
                  },
                  {
                    "type": 8,
                    "boolean": true
                  }
                ]
              }
            ]
          }
        }
      ]
    },
    "clientAnnotations": {
      "isEditedByUser": true
    },
    "isRequired": true
  },
  {
    "instance": {
      "key": {
        "publicId": "logging",
        "versionId": "1"
      },
      "param": [
        {
          "key": "environments",
          "value": {
            "type": 1,
            "string": "debug"
          }
        }
      ]
    },
    "clientAnnotations": {
      "isEditedByUser": true
    },
    "isRequired": true
  }
]


___TESTS___

scenarios:
- name: Injects the snippet and initialises it when the visitor cookie is present
  code: |-
    const mockData = {
      siteKey: 'pk_live_abcdefghijklmnopqrstuvwxyz012345',
      cookieName: 'so_vid',
      requireConsent: false
    };

    let requestedCookie;
    mock('getCookieValues', (name) => {
      requestedCookie = name;
      return ['vis_0123456789abcdefghjkmnpqrs'];
    });

    let injectedUrl;
    mock('injectScript', (url, onSuccess) => {
      injectedUrl = url;
      onSuccess();
    });

    let initPath;
    let initOptions;
    mock('callInWindow', (path, options) => {
      initPath = path;
      initOptions = options;
    });

    runCode(mockData);

    assertThat(requestedCookie).isEqualTo('so_vid');
    assertThat(injectedUrl).isEqualTo('https://api.sendops.dev/sendops.js');
    assertThat(initPath).isEqualTo('sendops.init');
    assertThat(initOptions.siteKey).isEqualTo(mockData.siteKey);
    assertThat(initOptions.visitorId).isEqualTo('vis_0123456789abcdefghjkmnpqrs');
    assertThat(initOptions.requireConsent).isEqualTo(false);
    assertApi('gtmOnSuccess').wasCalled();
- name: Loads nothing when the visitor cookie is absent
  code: |-
    const mockData = {
      siteKey: 'pk_live_abcdefghijklmnopqrstuvwxyz012345',
      cookieName: 'so_vid',
      requireConsent: false
    };

    mock('getCookieValues', () => {
      return [];
    });

    runCode(mockData);

    assertApi('injectScript').wasNotCalled();
    assertApi('callInWindow').wasNotCalled();
    assertApi('gtmOnSuccess').wasCalled();
- name: Reads a custom cookie name
  code: |-
    const mockData = {
      siteKey: 'pk_live_abcdefghijklmnopqrstuvwxyz012345',
      cookieName: 'acme_vid',
      requireConsent: true
    };

    let requestedCookie;
    mock('getCookieValues', (name) => {
      requestedCookie = name;
      return ['vis_zyxwvtsrqpnmkjhgfedcba9876'];
    });

    mock('injectScript', (url, onSuccess) => {
      onSuccess();
    });

    let initOptions;
    mock('callInWindow', (path, options) => {
      initOptions = options;
    });

    runCode(mockData);

    assertThat(requestedCookie).isEqualTo('acme_vid');
    assertThat(initOptions.cookieName).isEqualTo('acme_vid');
    assertThat(initOptions.requireConsent).isEqualTo(true);
- name: Reports a failed download to GTM
  code: |-
    const mockData = {
      siteKey: 'pk_live_abcdefghijklmnopqrstuvwxyz012345',
      cookieName: 'so_vid',
      requireConsent: false
    };

    mock('getCookieValues', () => {
      return ['vis_0123456789abcdefghjkmnpqrs'];
    });

    mock('injectScript', (url, onSuccess, onFailure) => {
      onFailure();
    });

    runCode(mockData);

    assertApi('gtmOnFailure').wasCalled();
    assertApi('callInWindow').wasNotCalled();
- name: A tag with no tag type saved still behaves as Page visit
  code: |-
    const mockData = {
      siteKey: 'pk_live_abcdefghijklmnopqrstuvwxyz012345',
      cookieName: 'so_vid',
      requireConsent: false
    };

    mock('getCookieValues', () => {
      return ['vis_0123456789abcdefghjkmnpqrs'];
    });

    mock('injectScript', (url, onSuccess) => {
      onSuccess();
    });

    let calledPath;
    mock('callInWindow', (path) => {
      calledPath = path;
    });

    runCode(mockData);

    assertThat(mockData.tagType).isUndefined();
    assertThat(calledPath).isEqualTo('sendops.init');
    assertApi('gtmOnSuccess').wasCalled();
- name: Track event sends the name and properties through sendops.track
  code: |-
    const mockData = {
      tagType: 'track_event',
      siteKey: 'pk_live_abcdefghijklmnopqrstuvwxyz012345',
      cookieName: 'so_vid',
      eventName: 'site_pricing_viewed',
      eventProperties: [
        {name: 'plan', value: 'growth'},
        {name: 'seats', value: '12'}
      ]
    };

    mock('getCookieValues', () => {
      return ['vis_0123456789abcdefghjkmnpqrs'];
    });

    let injectedUrl;
    mock('injectScript', (url, onSuccess) => {
      injectedUrl = url;
      onSuccess();
    });

    let trackPath;
    let trackName;
    let trackProperties;
    mock('callInWindow', (path, name, properties) => {
      trackPath = path;
      trackName = name;
      trackProperties = properties;
    });

    runCode(mockData);

    assertThat(injectedUrl).isEqualTo('https://api.sendops.dev/sendops.js');
    assertThat(trackPath).isEqualTo('sendops.track');
    assertThat(trackName).isEqualTo('site_pricing_viewed');
    assertThat(trackProperties).isEqualTo({plan: 'growth', seats: '12'});
    assertApi('gtmOnSuccess').wasCalled();
- name: Track event sends nothing when the visitor cookie is absent
  code: |-
    const mockData = {
      tagType: 'track_event',
      siteKey: 'pk_live_abcdefghijklmnopqrstuvwxyz012345',
      cookieName: 'so_vid',
      eventName: 'site_pricing_viewed',
      eventProperties: [
        {name: 'plan', value: 'growth'}
      ]
    };

    mock('getCookieValues', () => {
      return [];
    });

    runCode(mockData);

    assertApi('injectScript').wasNotCalled();
    assertApi('callInWindow').wasNotCalled();
    assertApi('gtmOnSuccess').wasCalled();
- name: Track event drops a property name that breaks the key rule
  code: |-
    const mockData = {
      tagType: 'track_event',
      siteKey: 'pk_live_abcdefghijklmnopqrstuvwxyz012345',
      cookieName: 'so_vid',
      eventName: 'site_demo_requested',
      eventProperties: [
        {name: 'Plan Name', value: 'growth'},
        {name: '2nd_touch', value: 'yes'},
        {name: 'unset', value: undefined},
        {name: 'plan', value: 'growth'}
      ]
    };

    mock('getCookieValues', () => {
      return ['vis_0123456789abcdefghjkmnpqrs'];
    });

    mock('injectScript', (url, onSuccess) => {
      onSuccess();
    });

    let trackProperties;
    mock('callInWindow', (path, name, properties) => {
      trackProperties = properties;
    });

    runCode(mockData);

    assertThat(trackProperties).isEqualTo({plan: 'growth'});
    assertApi('gtmOnSuccess').wasCalled();
- name: Track event keeps an empty string but drops a property with no value
  code: |-
    const mockData = {
      tagType: 'track_event',
      siteKey: 'pk_live_abcdefghijklmnopqrstuvwxyz012345',
      cookieName: 'so_vid',
      eventName: 'site_demo_requested',
      eventProperties: [
        {name: 'note', value: ''},
        {name: 'unset', value: undefined},
        {name: 'missing', value: null}
      ]
    };

    mock('getCookieValues', () => {
      return ['vis_0123456789abcdefghjkmnpqrs'];
    });

    mock('injectScript', (url, onSuccess) => {
      onSuccess();
    });

    let trackProperties;
    mock('callInWindow', (path, name, properties) => {
      trackProperties = properties;
    });

    runCode(mockData);

    assertThat(trackProperties).isEqualTo({note: ''});
    assertApi('gtmOnSuccess').wasCalled();
- name: Track event reports a failed download to GTM
  code: |-
    const mockData = {
      tagType: 'track_event',
      siteKey: 'pk_live_abcdefghijklmnopqrstuvwxyz012345',
      cookieName: 'so_vid',
      eventName: 'site_pricing_viewed',
      eventProperties: []
    };

    mock('getCookieValues', () => {
      return ['vis_0123456789abcdefghjkmnpqrs'];
    });

    mock('injectScript', (url, onSuccess, onFailure) => {
      onFailure();
    });

    runCode(mockData);

    assertApi('gtmOnFailure').wasCalled();
    assertApi('callInWindow').wasNotCalled();


___NOTES___

The tag has two types, chosen by the "Tag type" select.

Page visit is the one you install first, on Initialization - All Pages. It runs
before the rest of the container, is safe on every page of every property under
the cookie's domain, and sends one site_visit per browser session rather than
one per pageview. A tag saved before Track event existed has no tag type stored
and keeps behaving exactly this way.

Track event turns any GTM trigger into a SendOps activity with no page code.
Attach it to a trigger, give it an event name, and the event lands in SendOps
where a Drip Workflow can enter on it. Worked example:

  Trigger: Page View, with the condition Page Path contains /pricing
  Tag:     SendOps Website Beacon, Tag type = Track event
           Event name = site_pricing_viewed
           Properties (optional): plan = {{DLV - plan}}

  Workflow: enter on activity.site_pricing_viewed

A Page visit tag must still be installed on your pages. It is the tag that
calls sendops.init, and without it a Track event tag has nothing initialised to
send through. Order does not matter: sendops.js queues up to ten track calls
made before init and replays them once init runs, so a Track event tag that
fires first still reports.

Event names must match ^site_[a-z0-9_]{1,60}$. Anything else is dropped.

Property names must match ^[a-z][a-z0-9_]{0,31}$; the tag drops the rest before
sending and logs which in debug mode. SendOps keeps at most ten properties of
your own per event and silently drops any beyond that, so list the ones you
will filter on first.

Every site_* event already carries path, referrer, title, utm_source,
utm_medium and utm_campaign without you listing them, and a workflow can filter
on those six with no setup:

  enter on activity.site_pricing_viewed
    where exists(activity.site_pricing_viewed where path starts with "/pricing")

A property of your own has to be promoted before a workflow can filter on it,
through POST /v1/activity-properties or the audience schema file in a connected
repository. Once promoted it filters the same way:

  enter on activity.site_pricing_viewed
    where exists(activity.site_pricing_viewed where plan = "growth")

Custom events can also come from the data layer, which is the right choice when
the event is raised by your own page code rather than by a GTM trigger. The
snippet watches the data layer itself, so no second tag is needed:

  dataLayer.push({event: 'sendops_track', name: 'site_pricing_viewed'});
  dataLayer.push({event: 'sendops_track', name: 'site_demo_requested',
                  properties: {plan: 'growth'}});

The tag never writes a cookie. The visitor id comes from your own server, which
calls POST /v1/contacts/identify and returns the id as a first-party HTTP
cookie. That is what keeps the id alive beyond Safari's 7-day cap on
script-written cookies, so nothing here may set one. Either tag type does
nothing at all, and loads nothing, when the cookie is absent.

Consent: the tag declares analytics_storage, so with Consent Mode configured
GTM holds it until analytics_storage is granted. Leave the "Wait for in-page
consent" checkbox off in that setup. Turn it on only when your consent banner
calls sendops.consent(true) directly instead of going through Consent Mode.
The checkbox applies to the Page visit type, which is where init happens.
