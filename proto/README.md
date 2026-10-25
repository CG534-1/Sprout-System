# Sprout API contracts

Protobuf definitions for the Sprout care app (plants and pets). Served with [Connect](https://connectrpc.com) over HTTP, using JSON or binary Protobuf.

## Packages

- `sprout.v1`: the current API.

## Services

| Service | Method | What it does |
|---|---|---|
| `NotificationService` | `ListNotifications` | The signed-in account's newest notifications (at most 50). Notes read before today, in the caller's time zone, are cleared first. |

## Calling it

Every method needs the caller's access token:

```
POST /sprout.v1.NotificationService/ListNotifications
Authorization: Bearer <access token>
X-Utc-Offset-Minutes: <minutes east of UTC>
Content-Type: application/json

{}
```

Errors use Connect codes. A missing or expired token returns `unauthenticated`.

## Compatibility

Changes are checked with `buf breaking` against this module before they are pushed. Field numbers are never reused or renumbered. In JSON, fields at their default value (`false`, `0`, `""`, empty lists) are left out.
