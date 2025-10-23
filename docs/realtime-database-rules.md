# Firebase Realtime Database flow & security blueprint

This document summarizes how the existing Flutter code handles live rider tracking and
translates those requirements into a secure Firebase Realtime Database (RTDB) rule set.

## Code-driven data flow

* The rider application subscribes to high accuracy GPS updates (every ~10 metres) and pushes
  the latest latitude/longitude plus a timestamp to Firestore under the rider's UID. `SetOptions.merge(true)`
  is used so the location document stays mutable for recurring writes.【F:lib/pages/assignmentList.dart†L60-L108】
* Rider distance checks rely on reading the rider's latest coordinates from the same location
  document in order to calculate the gap between the rider and a pickup address.【F:lib/pages/assignmentList.dart†L480-L520】
* The customer-facing tracking screen streams documents from `delivery_tracking`, filtered by the
  logged-in sender UID and (optionally) a specific delivery ID. Each document aggregates metadata
  (sender, receiver, rider, status) together with the current rider position. Multiple field names are
  supported for location payloads so that different writer implementations remain compatible.【F:lib/pages/trackDelivery.dart†L132-L208】【F:lib/pages/trackDelivery.dart†L892-L924】

Although the current implementation stores the real-time data inside Cloud Firestore, the same
structure can be mirrored inside RTDB so that the rider publishes frequent updates while the user
side subscribes to those coordinates.

## Recommended RTDB structure

| Path | Purpose | Required fields |
| --- | --- | --- |
| `/roles/{uid}` | Boolean flags maintained by trusted code to mark admins or service accounts that may bypass end-user restrictions. | `{ "isAdmin": true }` (optional) |
| `/riderLocations/{riderUid}` | Latest unconstrained GPS point for a rider (used for distance and background checks). | `lat`, `lng`, `updated_at` |
| `/deliveryTracking/{deliveryId}` | Aggregated view of a delivery used by the customer tracking UI. | `sender_uid`, `receiver_uid`, `rider_uid`, `status_code`, `location/{lat,lng,updated_at}` |

Server-side automation (Cloud Functions, trusted backend, or privileged admin clients) should be
responsible for creating the delivery nodes and copying role metadata so that security rules can
make authorization decisions without cross-service lookups.

## Security rules (database.rules.json)

Deploy the following rule set to `firebase deploy --only database` (or add it to `firebase.json`). It
enforces least-privilege access where only the assigned rider can write their location, while the
sender, receiver, rider, or admins can subscribe to the coordinates.

```json
{
  "rules": {
    "roles": {
      "$uid": {
        ".read": "auth != null && auth.uid == $uid",
        ".write": "false",
        "isAdmin": {
          ".validate": "newData.isBoolean()"
        }
      }
    },
    "riderLocations": {
      "$riderUid": {
        ".read": "auth != null && (auth.uid == $riderUid || root.child('roles').child(auth.uid).child('isAdmin').val() == true)",
        ".write": "auth != null && auth.uid == $riderUid",
        ".validate": "newData.hasChildren(['lat','lng','updated_at'])",
        "lat": {
          ".validate": "newData.isNumber() && newData.val() >= -90 && newData.val() <= 90"
        },
        "lng": {
          ".validate": "newData.isNumber() && newData.val() >= -180 && newData.val() <= 180"
        },
        "updated_at": {
          ".validate": "newData.isNumber() || newData.val() == now"
        }
      }
    },
    "deliveryTracking": {
      "$deliveryId": {
        ".read": "auth != null && (auth.uid == data.child('sender_uid').val() || auth.uid == data.child('receiver_uid').val() || auth.uid == data.child('rider_uid').val() || root.child('roles').child(auth.uid).child('isAdmin').val() == true)",
        ".write": "false",
        "sender_uid": { ".validate": "newData.isString()" },
        "receiver_uid": { ".validate": "newData.isString()" },
        "rider_uid": { ".validate": "newData.isString()" },
        "status_code": {
          ".validate": "newData.isNumber() && newData.val() >= 1 && newData.val() <= 4"
        },
        "item_name": {
          ".validate": "newData.isString() || !newData.exists()"
        },
        "location": {
          ".write": "auth != null && auth.uid == data.parent().child('rider_uid').val()",
          ".validate": "newData.hasChildren(['lat','lng','updated_at'])",
          "lat": {
            ".validate": "newData.isNumber() && newData.val() >= -90 && newData.val() <= 90"
          },
          "lng": {
            ".validate": "newData.isNumber() && newData.val() >= -180 && newData.val() <= 180"
          },
          "updated_at": {
            ".validate": "newData.isNumber() || newData.val() == now"
          }
        },
        "$other": {
          ".validate": "true"
        }
      }
    }
  }
}
```

## Operational notes

1. Pre-create each `/deliveryTracking/{deliveryId}` node from trusted code so that riders only need
   to patch `location/*`. That prevents them from forging participation in a delivery.
2. Mirror the role or assignment metadata that rules depend on (e.g. sender, receiver, rider, admin
   flags) inside RTDB. Rules cannot look up Cloud Firestore or other services, so the data must be
   colocated.
3. When writing timestamps from clients, pass `ServerValue.timestamp` so that the `.validate`
   clause accepts the write via `newData.val() == now`.
4. Add additional child validations (for example, `updated_at` monotonic checks) if you need
   stricter guarantees once the end-to-end flow is stable.
