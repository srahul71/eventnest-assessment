# REVIEW

## 1. Order IDOR exposed other attendees' purchases
- File/line: `app/controllers/api/v1/orders_controller.rb:5-22`, `app/controllers/api/v1/orders_controller.rb:80-81`
- Category: Security
- Severity: Critical
- Description: The original implementation used unscoped `Order.all` and `Order.find(params[:id])`, which allowed any authenticated attendee to list, view, and cancel other users' orders by guessing IDs. That exposed payment status, confirmation numbers, event details, and allowed destructive changes across accounts.
- Recommended fix: Scope every order lookup to `current_user.orders` and return a consistent `404` for records the current user does not own. Add request specs that prove cross-user reads and cancels are blocked.
- Proof from running app:
```bash
ATTENDEE_TOKEN=$(curl -s -X POST http://localhost:3000/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"ananya@example.com","password":"password123"}' \
  | ruby -rjson -e 'puts JSON.parse(STDIN.read)["token"]')

curl -s http://localhost:3000/api/v1/orders/2 \
  -H "Authorization: Bearer $ATTENDEE_TOKEN"
```
Observed before fix:
```json
{"id":2,"confirmation_number":"EVN-E5F6G7H8","status":"confirmed","total_amount":4999.0,"event":{"id":2,"title":"RailsConf India 2025","starts_at":"..."},"items":[...],"payment":{"status":"completed","provider_reference":"ch_xyz789ghi012"}}
```

## 2. Any authenticated user could create or alter ticket inventory
- File/line: `app/controllers/api/v1/ticket_tiers_controller.rb:23-53`
- Category: Security
- Severity: Critical
- Description: Ticket tier creation, update, and deletion only required authentication; there was no organizer ownership check. The controller also permits `sold_count`, so an attendee can directly manipulate inventory and sales numbers for someone else’s event.
- Recommended fix: Require organizer ownership on tier mutations, forbid mass assignment of `sold_count`, and enforce server-side inventory changes through purchase/refund workflows only.
- Proof from running app:
```bash
ATTENDEE_TOKEN=$(curl -s -X POST http://localhost:3000/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"ananya@example.com","password":"password123"}' \
  | ruby -rjson -e 'puts JSON.parse(STDIN.read)["token"]')

curl -s -X POST http://localhost:3000/api/v1/events/1/ticket_tiers \
  -H "Authorization: Bearer $ATTENDEE_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"ticket_tier":{"name":"Fraud Tier","price":1,"quantity":500,"sold_count":499}}'
```
Observed response:
```json
{"id":8,"name":"Fraud Tier","price":"1.0","quantity":500,"sold_count":499,"event_id":1,...}
```

## 3. Event search/sort accepted unsafe SQL fragments
- File/line: `app/controllers/api/v1/events_controller.rb:12-25`
- Category: Security
- Severity: High
- Description: The original search clause interpolated `params[:search]` directly into SQL, and the sort clause passed `params[:sort_by]` directly into `order`. That made the endpoint vulnerable to SQL injection and arbitrary SQL fragments in ordering.
- Recommended fix: Use parameterized search with `sanitize_sql_like`, restrict sorting to an allowlist, and add request coverage around malicious input.

## 4. Order creation trusted foreign ticket tier IDs without validating event ownership
- File/line: `app/controllers/api/v1/orders_controller.rb:49-63`
- Category: Data Integrity
- Severity: High
- Description: `OrdersController#create` looks up `TicketTier` by raw ID and never verifies that the tier belongs to the requested event, is on sale, or has enough remaining inventory. A client can mix tiers from another event into an order and create inconsistent booking and payment data.
- Recommended fix: Resolve tiers through `event.ticket_tiers`, validate sales windows and available quantity before saving, and wrap reservation/payment state changes in a transaction.

## 5. Login endpoint leaks whether an email exists
- File/line: `app/controllers/api/v1/auth_controller.rb:17-28`
- Category: Security
- Severity: Medium
- Description: The login response distinguishes `Invalid password` from `No account found with that email`. That enables straightforward account enumeration and makes credential-stuffing lists easier to verify.
- Recommended fix: Return the same generic authentication error for unknown emails and bad passwords, and log the precise reason only on the server side.

## 6. Event and order side effects run synchronously on the request path
- File/line: `app/models/event.rb:29-52`, `app/models/order.rb:45-75`
- Category: Performance
- Severity: Medium
- Description: Event save triggers a blocking `sleep(0.1)` geocoding stub and multiple `deliver_now` callbacks, while orders synchronously create payments and send emails on state changes. Those side effects increase latency, amplify failure modes, and create slow cascading behavior during high-volume event or order activity.
- Recommended fix: Move non-critical work to async jobs, replace the geocoding stub with a real service boundary, and keep request transactions focused on durable state changes.

## 7. Test execution was coupled to container env vars and Redis-backed jobs
- File/line: `spec/rails_helper.rb:1-5`, `config/application.rb:13-17`, `config/environments/test.rb:13-15`
- Category: Testing
- Severity: Medium
- Description: Running specs inside the `web` container inherited `RAILS_ENV=development` and `DATABASE_URL`, while the application defaulted Active Job to Sidekiq. That caused tests to hit the wrong database and attempt Redis connections, producing environment failures unrelated to application behavior.
- Recommended fix: Force `RAILS_ENV=test` in the spec boot path, clear `DATABASE_URL` before loading Rails in tests, and keep the test adapter on `:test` to avoid Redis.
