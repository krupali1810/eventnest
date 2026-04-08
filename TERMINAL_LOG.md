# EventNest Terminal Log

Terminal output and API proof captured during the assessment. This file includes setup output, test runs, curl demonstrations, and before/after proof for the first two critical issues from `REVIEW.md`.

## Setup Output

```bash
# Clone and enter the repo
git clone <repo-url> && cd eventnest

# Start the app and database
docker-compose up --build

# In a separate terminal, set up the database
docker-compose exec web rails db:create db:migrate db:seed

# Run the test suite
docker-compose exec web bundle exec rspec

# The API is now running at http://localhost:3000
```

## Initial Test Suite Run

### Command

```bash
docker-compose exec web bundle exec rspec
```

### Output

```text
FFFFFFF......F.....2026-04-07T16:38:15.994Z pid=69 tid=2sl INFO: Sidekiq 7.3.9 connecting to Redis with options {:size=>10, :pool_name=>"internal", :url=>nil}
FF........

Finished in 9.61 seconds (files took 1.62 seconds to load)
29 examples, 10 failures

Failed examples:

rspec ./spec/controllers/events_controller_spec.rb:13 # Api::V1::EventsController GET /api/v1/events returns published upcoming events
rspec ./spec/controllers/events_controller_spec.rb:26 # Api::V1::EventsController POST /api/v1/events creates an event
rspec ./spec/controllers/events_controller_spec.rb:45 # Api::V1::EventsController PUT /api/v1/events/:id updates an event
rspec ./spec/controllers/events_controller_spec.rb:57 # Api::V1::EventsController DELETE /api/v1/events/:id deletes an event
rspec ./spec/controllers/orders_controller_spec.rb:15 # Api::V1::OrdersController GET /api/v1/orders returns orders
rspec ./spec/controllers/orders_controller_spec.rb:27 # Api::V1::OrdersController GET /api/v1/orders/:id returns order details
rspec ./spec/controllers/orders_controller_spec.rb:37 # Api::V1::OrdersController POST /api/v1/orders/:id/cancel cancels a pending order
rspec ./spec/models/event_spec.rb:34 # Event scopes returns upcoming published events
rspec ./spec/models/order_spec.rb:19 # Order#confirm! sets status to confirmed
rspec ./spec/models/order_spec.rb:27 # Order#cancel! sets status to cancelled
```

## Runtime Issue: Missing Redis / Sidekiq Dependency

### Cancel order request

```bash
curl -X POST http://localhost:3000/api/v1/orders/2/cancel \
  -H "Authorization: Bearer eyJhbGciOiJIUzI1NiJ9.eyJ1c2VyX2lkIjozLCJleHAiOjE3NzU2NjY0MDZ9.mq4A7_mWi9zezqExVs0r7Kn-ybFk-_3A-K6Z5mdS_N8"
```

### Response

```json
{"status":500,"error":"Internal Server Error","exception":"#\u003cRedisClient::CannotConnectError: Connection refused - connect(2) for 127.0.0.1:6379\u003e","traces":{"Application Trace":[],"Framework Trace":[],"Full Trace":[]}}
```

### Note

The application is configured to enqueue background jobs through Sidekiq, but the current Docker setup does not provide a reachable Redis service. This causes normal write flows such as order cancellation to fail with `500 Internal Server Error`, so the infrastructure issue needs to be resolved before relying on cancellation-based proof.

## Bug Proof 1: Any Authenticated User Can Access Another User's Order

### Login as attendee

```bash
curl -X POST http://localhost:3000/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"ananya@example.com","password":"password123"}'
```

### Response

```json
{"token":"eyJhbGciOiJIUzI1NiJ9.eyJ1c2VyX2lkIjozLCJleHAiOjE3NzU2NjY0MDZ9.mq4A7_mWi9zezqExVs0r7Kn-ybFk-_3A-K6Z5mdS_N8","user":{"id":3,"name":"Ananya Gupta","email":"ananya@example.com","role":"attendee"}}
```

### Read another attendee's order

```bash
curl http://localhost:3000/api/v1/orders/2 \
  -H "Authorization: Bearer eyJhbGciOiJIUzI1NiJ9.eyJ1c2VyX2lkIjozLCJleHAiOjE3NzU2NjY0MDZ9.mq4A7_mWi9zezqExVs0r7Kn-ybFk-_3A-K6Z5mdS_N8"
```

### Response

```json
{"id":2,"confirmation_number":"EVN-E5F6G7H8","status":"confirmed","total_amount":4999.0,"event":{"id":2,"title":"RailsConf India 2025","starts_at":"2026-05-12T13:33:10.765Z"},"items":[{"ticket_tier":"Premium (with Workshop)","quantity":1,"unit_price":4999.0,"subtotal":4999.0}],"payment":{"status":"completed","provider_reference":"ch_xyz789ghi012"}}
```

## Bug Proof 2: Any Authenticated User Can Update Another Organizer's Event

### Login as attendee

```bash
curl -X POST http://localhost:3000/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"ananya@example.com","password":"password123"}'
```

### Response

```json
{"token":"eyJhbGciOiJIUzI1NiJ9.eyJ1c2VyX2lkIjozLCJleHAiOjE3NzU2NjcyMzZ9.1Xqzfzl71Ri9FFaYIVNIx_Ek8gCdA98aRafUHIM8BRs","user":{"id":3,"name":"Ananya Gupta","email":"ananya@example.com","role":"attendee"}}
```

### Update organizer-owned event

```bash
curl -X PUT http://localhost:3000/api/v1/events/1 \
  -H "Authorization: Bearer eyJhbGciOiJIUzI1NiJ9.eyJ1c2VyX2lkIjozLCJleHAiOjE3NzU2NjcyMzZ9.1Xqzfzl71Ri9FFaYIVNIx_Ek8gCdA98aRafUHIM8BRs" \
  -H "Content-Type: application/json" \
  -d '{"event":{"title":"Hacked Event Title"}}'
```

### Response

```json
{"title":"Hacked Event Title","user_id":1,"city":"Mumbai","id":1,"description":"A two-day celebration of independent music featuring artists from across India.","venue":"Bandra Fort Amphitheatre, Mumbai","starts_at":"2026-04-28T13:33:10.737Z","ends_at":"2026-04-30T13:33:10.737Z","status":"published","category":"music","max_capacity":500,"created_at":"2026-04-07T13:33:10.759Z","updated_at":"2026-04-08T11:12:52.472Z"}
```

## Before/After Proof for Fix 1: Orders Authorization

### Before fix: cross-user order access

```bash
curl http://localhost:3000/api/v1/orders/2 \
  -H "Authorization: Bearer eyJhbGciOiJIUzI1NiJ9.eyJ1c2VyX2lkIjozLCJleHAiOjE3NzU2NjcyMzZ9.1Xqzfzl71Ri9FFaYIVNIx_Ek8gCdA98aRafUHIM8BRs"
```

```json
{"id":2,"confirmation_number":"EVN-E5F6G7H8","status":"confirmed","total_amount":4999.0,"event":{"id":2,"title":"RailsConf India 2025","starts_at":"2026-05-12T13:33:10.765Z"},"items":[{"ticket_tier":"Premium (with Workshop)","quantity":1,"unit_price":4999.0,"subtotal":4999.0}],"payment":{"status":"completed","provider_reference":"ch_xyz789ghi012"}}
```

### After fix: cross-user order access blocked

```bash
curl http://localhost:3000/api/v1/orders/2 \
  -H "Authorization: Bearer eyJhbGciOiJIUzI1NiJ9.eyJ1c2VyX2lkIjozLCJleHAiOjE3NzU2NjcyMzZ9.1Xqzfzl71Ri9FFaYIVNIx_Ek8gCdA98aRafUHIM8BRs"
```

```json
{"error":"Order not found"}
```

### Before fix: cross-user cancellation

```bash
curl -X POST http://localhost:3000/api/v1/orders/2/cancel \
  -H "Authorization: Bearer eyJhbGciOiJIUzI1NiJ9.eyJ1c2VyX2lkIjozLCJleHAiOjE3NzU2NjcyMzZ9.1Xqzfzl71Ri9FFaYIVNIx_Ek8gCdA98aRafUHIM8BRs"
```

```json
{"message":"Order cancelled","status":"cancelled"}
```

### After fix: cross-user cancellation blocked

```bash
curl -X POST http://localhost:3000/api/v1/orders/2/cancel \
  -H "Authorization: Bearer eyJhbGciOiJIUzI1NiJ9.eyJ1c2VyX2lkIjozLCJleHAiOjE3NzU2NjcyMzZ9.1Xqzfzl71Ri9FFaYIVNIx_Ek8gCdA98aRafUHIM8BRs"
```

```json
{"error":"Order not found"}
```

## Before/After Proof for Fix 2: Event Ownership Enforcement

### Before fix: non-owner event update succeeds

```bash
curl -X PUT http://localhost:3000/api/v1/events/1 \
  -H "Authorization: Bearer eyJhbGciOiJIUzI1NiJ9.eyJ1c2VyX2lkIjozLCJleHAiOjE3NzU2NjcyMzZ9.1Xqzfzl71Ri9FFaYIVNIx_Ek8gCdA98aRafUHIM8BRs" \
  -H "Content-Type: application/json" \
  -d '{"event":{"title":"Hacked Event Title"}}'
```

```json
{"title":"Hacked Event Title","user_id":1,"city":"Mumbai","id":1,"description":"A two-day celebration of independent music featuring artists from across India.","venue":"Bandra Fort Amphitheatre, Mumbai","starts_at":"2026-04-28T13:33:10.737Z","ends_at":"2026-04-30T13:33:10.737Z","status":"published","category":"music","max_capacity":500,"created_at":"2026-04-07T13:33:10.759Z","updated_at":"2026-04-08T11:12:52.472Z"}
```

### After fix: non-owner event update blocked

```bash
curl -X PUT http://localhost:3000/api/v1/events/1 \
  -H "Authorization: Bearer eyJhbGciOiJIUzI1NiJ9.eyJ1c2VyX2lkIjozLCJleHAiOjE3NzU2NjcyMzZ9.1Xqzfzl71Ri9FFaYIVNIx_Ek8gCdA98aRafUHIM8BRs" \
  -H "Content-Type: application/json" \
  -d '{"event":{"title":"Hacked Event Title"}}'
```

```json
{"error":"Forbidden"}
```

### Before fix: non-owner event deletion succeeds

```bash
curl -X DELETE http://localhost:3000/api/v1/events/1 \
  -H "Authorization: Bearer eyJhbGciOiJIUzI1NiJ9.eyJ1c2VyX2lkIjozLCJleHAiOjE3NzU2NjcyMzZ9.1Xqzfzl71Ri9FFaYIVNIx_Ek8gCdA98aRafUHIM8BRs" -i
```

```text
HTTP/1.1 204 No Content
x-frame-options: SAMEORIGIN
x-xss-protection: 0
x-content-type-options: nosniff
x-permitted-cross-domain-policies: none
referrer-policy: strict-origin-when-cross-origin
cache-control: no-cache
x-request-id: ca0e9d8b-5310-44e0-b935-6b3c46449f2e
x-runtime: 0.065290
server-timing: start_processing.action_controller;dur=0.03, sql.active_record;dur=10.87, instantiation.active_record;dur=1.12, transaction.active_record;dur=28.32, process_action.action_controller;dur=44.03
vary: Origin
```

### After fix: non-owner event deletion blocked

```bash
curl -X DELETE http://localhost:3000/api/v1/events/1 \
  -H "Authorization: Bearer eyJhbGciOiJIUzI1NiJ9.eyJ1c2VyX2lkIjozLCJleHAiOjE3NzU2NjcyMzZ9.1Xqzfzl71Ri9FFaYIVNIx_Ek8gCdA98aRafUHIM8BRs" -i
```

```text
HTTP/1.1 403 Forbidden
x-frame-options: SAMEORIGIN
x-xss-protection: 0
x-content-type-options: nosniff
x-permitted-cross-domain-policies: none
referrer-policy: strict-origin-when-cross-origin
content-type: application/json; charset=utf-8
vary: Accept, Origin
cache-control: no-cache
x-request-id: ded83892-ae3d-40a8-b141-a1ebe57af7e1
x-runtime: 0.026204
server-timing: start_processing.action_controller;dur=0.03, sql.active_record;dur=0.99, instantiation.active_record;dur=0.13, halted_callback.action_controller;dur=0.02, process_action.action_controller;dur=6.02
Content-Length: 21

{"error":"Forbidden"}
```

## Final Test Suite Run

### Command

```bash
docker-compose exec web bundle exec rspec
```

### Output

```text
..........................2026-04-08T13:49:05.716Z pid=124 tid=2sc INFO: Sidekiq 7.3.9 connecting to Redis with options {:size=>10, :pool_name=>"internal", :url=>"redis://redis:6379/0"}
..........

Finished in 15.85 seconds (files took 1.62 seconds to load)
36 examples, 0 failures
```
