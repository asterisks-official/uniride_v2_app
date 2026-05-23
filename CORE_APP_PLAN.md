# UniRide — Core App Implementation Plan

> This is a **deployable, real product** (Android + iOS, university ride-sharing
> in Bangladesh), not a demo. Every phase ships with production states (loading /
> empty / error / offline), real error handling, and a Definition of Done — not
> a happy-path prototype. Safety and trust are first-class, because this matches
> strangers for shared rides.

Backend: live NestJS API at `https://uniride-v2-backend.onrender.com/api/v1`
(REST + Socket.IO). App: Flutter (Riverpod + GoRouter + Dio + Freezed).

---

## 1. Status

**Done**
- Auth slice: register → email OTP → login → forgot/reset, session restore, token refresh.
- Themed auth UI (sage-green).
- Rider verification flow ("Become a Rider": vehicle form + S3 doc upload, status states).
- Role model: passenger by default; RIDER granted only on admin approval.

**Now:** the core ride loop (this document).

---

## 2. Architecture & conventions (single source of truth)

- **Feature-first**: `lib/features/<feature>/{domain,data,presentation}`; shared in `core/` and `shared/`.
- **State**: Riverpod (`Notifier`/`AsyncNotifier`), no business logic in widgets.
- **Models**: Freezed + json_serializable. Backend success envelope is `{ data, meta }`; errors are `{ statusCode, error, message[], requestId }` (mapped by `api_exception_mapper`).
- **Networking**: single Dio via `ApiClient` with auth interceptor (401 → refresh → retry). S3 uploads use a clean Dio (no auth header).
- **Errors**: every repo maps `DioException` → `AppException`; every screen renders a real error state (no silent failures, no raw exceptions to users).
- **Theme**: reuse `AppTheme` (sage-green), `AppButton`, floating-label inputs, cards.

---

## 3. Cross-cutting Definition of Done (applies to EVERY phase)

A screen/feature is not "done" until:
1. **States**: loading (skeleton/spinner), **empty**, **error + retry**, and **offline** banner are all handled.
2. **Lists**: paginated + pull-to-refresh; image caching via `cached_network_image`.
3. **Failures**: surfaced as friendly messages; never crash, never show a raw 500.
4. **Permissions**: any OS permission (location, photos, notifications) has a request + denied/forever-denied path.
5. **Auth/role**: UI is role-adaptive; guarded actions check role; expired sessions route to login.
6. **Telemetry**: key actions logged (analytics) and crashes captured (Sentry).
7. **Tests**: notifier unit tests + at least one widget test for the main screen.
8. **A11y**: 44px tap targets, sufficient contrast, semantic labels on icons/buttons.

---

## 4. Phased delivery (vertical slices)

> Phases 0–2 need **no Maps key and no realtime** — fastest path to a usable app.
> Maps (3) and Socket.IO (4) are the externally-gated pieces.

### Phase 0 — Foundation hardening + app shell
- **Environment config / build flavors**: dev vs prod API base URL (stop hardcoding); `--dart-define` or flavor configs.
- Bottom-nav shell: **Home · My Rides · Alerts · Profile**.
- Real **Profile** screen (user info, trust score, stats, "Become a Rider", logout).
- Shared widgets: `RideCard`, `EmptyState`, `ErrorRetry`, `OfflineBanner`, skeletons.
- **Sentry** crash reporting + analytics scaffold; connectivity service.
- *DoD:* app boots into shell, offline banner works, crashes report to Sentry.

### Phase 1 — Discover & request (passenger core, no maps)
- Home **feed** (`GET /rides`): paginated, filter chips (now/today, female-only, proximity later), pull-to-refresh.
- **Ride detail** (`GET /rides/:id`): rider mini-profile + trust score; **Request to Join** (`POST /rides/:id/requests`) with optimistic state + dedupe.
- **My Rides** (passenger): requests / matched (`GET /rides/my`).
- *DoD:* a passenger can find, open, and request a ride; sees their pending/matched rides.

### Phase 2 — Offer & match (rider core, no maps)
- **Create ride** (`POST /rides`): location entry (manual now), date-time, fare, seats, gender pref; validation; RIDER-gated.
- **Manage requests** (`GET /rides/:id/requests`, `PATCH .../requests/:id`): accept/declines, seat math, auto-match.
- My Rides (rider): own offers + pending request counts; **cancel ride** with reason.
- *DoD:* full matching loop works end-to-end against the live backend.

### Phase 3 — Maps & location
- Google Maps key (Android + iOS), runtime location permission UX.
- Create-ride: tap-to-pin + place search (origin/dest), reverse-geocode addresses.
- Route preview + distance/ETA on cards & detail; proximity filter on feed.
- *DoD:* real location selection and route display.

### Phase 4 — Real-time active ride
- Socket.IO service (JWT auth, exponential reconnect, lifecycle on auth/app-state).
- **Active Ride** screen: live rider→passenger location, status banner, **Start ride** (rider), **Confirm completion** (both).
- Foreground location streaming during active ride (avoid background-location store review for v1).
- **SOS** button (schema `hasSos`) → alert + share location.
- *DoD:* a matched ride can be tracked live and completed by both parties.

### Phase 5 — In-ride chat
- Realtime messages (socket) + REST history; system messages; unread indicator; resend on failure.
- *DoD:* rider/passenger can message reliably within a ride.

### Phase 6 — Trust & safety (ratings, reports, blocking)
- Post-completion **rating sheet** (stars + tags + review); trust-score reflects it.
- **Report** a user (type/severity/description) and **block**.
- "Share my trip" with an external contact (deep link / SMS).
- *DoD:* users can rate, report, and feel safe; abuse has a path.

### Phase 7 — Payments (BDT)
- Decision required (see §7): real gateway (bKash / Nagad / SSLCommerz) vs **cash-confirm v1**.
- Payment status on ride completion; earnings view for riders (`/payments/earnings`).
- *DoD:* fare settlement is explicit and recorded.

### Phase 8 — Notifications & deep links
- FCM: foreground (in-app), background, and **tap → deep-link routing** to the relevant ride/chat.
- Alerts tab (`/notifications`) + unread badge on bottom nav; device registration on login (already sent at login).
- *DoD:* request-accepted / ride-started / message / rating events reach the user and route correctly.

### Phase 9 — Launch readiness (store-deployable)
- App icon + native splash; final bundle IDs (`app.uniride.*`); versioning.
- **Android**: signing keystore, Play Console, Data Safety form, permissions audit, target-SDK compliance, R8/obfuscation + `--split-debug-info`.
- **iOS**: signing/provisioning, `Info.plist` usage strings (location, photo library/camera, notifications), App Store privacy labels.
- **Privacy policy + ToS + consent**; account deletion path (already `DELETE /users/me`).
- Release CI/CD (build + sign + distribute); Sentry symbol upload.
- *DoD:* signed release builds pass internal testing and store review prerequisites.

---

## 5. UI / UX design

**Navigation:** persistent bottom nav (Home · My Rides · Alerts · Profile). A `+`
**FAB on Home, shown only to verified riders**, opens Create Ride. UI is
**role-adaptive** — passengers never see offer/create controls. Reuses the
sage-green theme. Currency **৳ (BDT)**; trust score shown as a ◍ ring (0–40 red,
41–70 amber, 71–100 green).

### Home feed
```
┌─────────────────────────────┐
│ UniRide              🔔 ●    │
│ Find a ride                 │
│ ┌─────────────────────────┐ │
│ │ 🔍  From  →  To         │ │
│ └─────────────────────────┘ │
│ [Now] [Today] [Female-only] │
│ ┌─────────────────────────┐ │
│ │ 👤 Shakib    ⭐4.8  ◍82  │ │
│ │ Campus Gate → Mirpur 10 │ │
│ │ 8:00 AM · ৳80 · 2 seats │ │
│ └─────────────────────────┘ │
│                     ( + )   │  ← riders only
│ [Home] [Rides] [Alerts] [Me]│
└─────────────────────────────┘
```
States: skeleton list → feed; empty ("No rides nearby — try widening your filters"); error+retry; offline banner.

### Ride detail
```
┌─────────────────────────────┐
│ ←  Ride details             │
│ [ route preview (Phase 3) ] │
│ Campus Gate  →  Mirpur 10   │
│ Today · 8:00 AM             │
│ 👤 Shakib  ⭐4.8 · ◍82      │
│ Honda · 2 seats · ৳80       │
│ Female-only: No             │
│ [     Request to Join     ] │
└─────────────────────────────┘
```
Button is contextual: Request → "Requested ✓ (cancel)" → if matched, "Open active ride". Owner (rider) sees request management instead.

### Create ride (rider)
```
┌─────────────────────────────┐
│ ←  Offer a ride             │
│ Origin       [ enter/map ]  │
│ Destination  [ enter/map ]  │
│ Date & time  [ 24 May 8:00 ]│
│ Fare (৳)     [ 80 ]         │
│ Seats        [ 2 ]          │
│ Gender pref  [ Any ▾ ]      │
│ [        Post ride        ] │
└─────────────────────────────┘
```

### Other screens (concise)
- **My Rides**: tabs *Upcoming · Active · History*; riders also see their offers + pending-request badges; cancel with reason.
- **Active Ride**: map + both markers, status banner (SEARCHING/MATCHED/IN_PROGRESS), SOS, chat entry, Confirm Completion.
- **Chat**: message list (user vs system bubbles), input, send-state, history on open.
- **Rating sheet**: 5-star + tag chips (punctual, safe, friendly…) + optional review.
- **Alerts**: notification list, unread badge, tap → deep link.
- **Profile**: avatar, name, university, trust-score ring, stats grid, Become-a-Rider, settings, logout, delete account.

---

## 6. Production readiness checklist
- **Security**: tokens in secure storage ✔; cert pinning (consider); no secrets in repo; Maps key restricted by signing/bundle id.
- **Privacy/compliance**: privacy policy + ToS, in-app consent, account + data deletion, minimal location retention.
- **Safety**: rider verification ✔, gender preference enforced, SOS, report/block, share-trip.
- **Reliability**: socket reconnect/backoff, request idempotency, offline queue for chat send.
- **Performance**: list pagination, image caching, avoid rebuild storms, lazy maps.
- **Observability**: Sentry (crashes), analytics funnel (signup → first ride), backend logs.
- **Quality**: unit + widget + 1 integration test (golden path); CI runs analyze + tests.
- **Release**: flavors (dev/prod), signed builds, versioning, store metadata, staged rollout.

---

## 7. Open decisions & risks
1. **Payments**: which BDT method for v1 — bKash/Nagad/SSLCommerz integration, or **cash-confirm** with status tracking only? (Gateway adds compliance + time.)
2. **Passenger-posted ride requests**: backend supports `RideType.REQUEST` but create is RIDER-only. Expose two-sided posting, or rider-offers-only for v1?
3. **Rejected rider resubmit**: backend profile-update doesn't reset status to PENDING — add a resubmit path.
4. **Maps**: need a Google Maps API key + billing enabled before Phase 3.
5. **Push**: confirm the FCM project + `google-services.json` / `GoogleService-Info.plist`.
6. **Background location**: foreground-only for v1 to ease store review; revisit if needed.
7. **Email deliverability**: warm up `bitstreamhq.com` (SPF/DKIM ✔, add DMARC) so OTPs don't spam-folder.

---

## 8. Suggested order to start
**Phase 0 → 1 → 2** gets a usable, testable matching app with zero external
keys. Maps (3) and realtime (4) follow once the Maps key + FCM project are ready.
Payments (7) and launch (9) are parallelizable workstreams.
