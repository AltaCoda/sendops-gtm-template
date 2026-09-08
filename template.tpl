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
  "description": "Sends one site_visit beacon per browser session to SendOps for a visitor your own server already identified. The tag only reads the first-party so_vid cookie your server set; it never writes a cookie and never generates an identifier, so Safari's 7-day cap on script-written cookies does not apply.",
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
    "type": "TEXT",
    "name": "siteKey",
    "displayName": "Site key",
    "simpleValueType": true,
    "help": "The publishable site key from SendOps → Settings → Website. Starts with pk_live_.",
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
    "type": "CHECKBOX",
    "name": "requireConsent",
    "checkboxText": "Wait for in-page consent before sending",
    "simpleValueType": true,
    "defaultValue": false,
    "help": "Leave off if you gate this tag with Consent Mode or a GTM trigger. Turn on only when a consent banner on the page calls sendops.consent(true) itself."
  }
]


___SANDBOXED_JS_FOR_WEB_TEMPLATE___

const getCookieValues = require('getCookieValues');
const injectScript = require('injectScript');
const callInWindow = require('callInWindow');
const log = require('logToConsole');

const SNIPPET_URL = 'https://api.sendops.dev/sendops.js';

const cookieName = data.cookieName || 'so_vid';
const values = getCookieValues(cookieName);
const visitorId = values && values.length ? values[0] : '';

// No identified visitor means nothing to report. Skip the download entirely
// rather than loading a script that would decide to do nothing.
if (!visitorId) {
  data.gtmOnSuccess();
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

  const onFailure = () => {
    log('SendOps Website Beacon: could not load ' + SNIPPET_URL);
    data.gtmOnFailure();
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


___NOTES___

Fire this tag on Initialization - All Pages so the beacon runs before the rest
of the container. It is safe on every page of every property under the cookie's
domain; the snippet sends one site_visit per browser session, not per pageview.

The tag never writes a cookie. The visitor id comes from your own server, which
calls POST /v1/contacts/identify and returns the id as a first-party HTTP
cookie. That is what keeps the id alive beyond Safari's 7-day cap on
script-written cookies, so nothing here may set one.

Custom events go through the data layer, not through a second tag:

  dataLayer.push({event: 'sendops_track', name: 'site_pricing_viewed'});
  dataLayer.push({event: 'sendops_track', name: 'site_demo_requested',
                  properties: {plan: 'growth'}});

Event names must match ^site_[a-z0-9_]{1,60}$. Anything else is dropped.

Consent: the tag declares analytics_storage, so with Consent Mode configured
GTM holds it until analytics_storage is granted. Leave the "Wait for in-page
consent" checkbox off in that setup. Turn it on only when your consent banner
calls sendops.consent(true) directly instead of going through Consent Mode.
