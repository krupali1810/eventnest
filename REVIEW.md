# EventNest Code Review

Code review findings prioritized by business impact. Each issue includes the affected file and lines, category, severity, a short description, and the recommended fix.

## 1. Orders are globally readable and cancellable by any authenticated user

- **File / Line:** `app/controllers/api/v1/orders_controller.rb:5-18`, `app/controllers/api/v1/orders_controller.rb:21-46`, `app/controllers/api/v1/orders_controller.rb:80-88`
- **Category:** Security
- **Severity:** Critical

The `index` action returns `Order.all`, and both `show` and `cancel` load orders with `Order.find(params[:id])` without scoping them to `current_user`. Any authenticated user can read another customer's order details, access payment metadata, and cancel another customer's order if they know or guess the ID.

**Recommended fix:** Scope all order access through `current_user.orders` and return `404` for records the current user does not own. Add request specs that cover cross-user access attempts for `index`, `show`, and `cancel`.

## 2. Any authenticated user can update or delete another organizer's event

- **File / Line:** `app/controllers/api/v1/events_controller.rb:89-102`
- **Category:** Security
- **Severity:** Critical

The `update` and `destroy` actions fetch events by raw ID and never verify that the current user owns the event. This allows an unrelated attendee or organizer to modify or delete another organizer's event, which directly compromises a core business asset.

**Recommended fix:** Restrict mutable event actions to the owning organizer by scoping lookups through `current_user.events` and enforcing organizer-only access. Add request specs proving non-owners cannot update or delete someone else's event.

## 3. Ticket tier endpoints allow unauthorized inventory changes and forged sales counts

- **File / Line:** `app/controllers/api/v1/ticket_tiers_controller.rb:23-47`, `app/controllers/api/v1/ticket_tiers_controller.rb:52-53`
- **Category:** Security
- **Severity:** High

Ticket tiers can be created, updated, or deleted by any authenticated user because the controller never checks ownership of the parent event. The permitted params also include `sold_count`, allowing a caller to manipulate reported sales and available inventory without going through the order flow.

**Recommended fix:** Require that the current user owns the event before allowing ticket tier mutations, and remove `sold_count` from permitted request parameters. Keep inventory counters system-managed and update them only through order-processing logic.

## 4. Event search and sorting accept unsafe SQL input

- **File / Line:** `app/controllers/api/v1/events_controller.rb:9-10`, `app/controllers/api/v1/events_controller.rb:21`
- **Category:** Security
- **Severity:** High

The search filter interpolates raw user input directly into SQL, and the sort clause passes `params[:sort_by]` straight into `order(...)`. This exposes a public endpoint to SQL injection, malformed queries, and attacker-controlled database work.

**Recommended fix:** Replace interpolated SQL with parameterized `LIKE` conditions and whitelist supported sort columns and directions. Add request specs for malicious `search` values and invalid `sort_by` parameters.

## 5. Public registration allows users to assign themselves privileged roles

- **File / Line:** `app/controllers/api/v1/auth_controller.rb:34-35` 
- **Category:** Security
- **Severity:** High

The registration endpoint permits `:role`, which means any new account can self-register as an `organizer` or `admin`. That breaks the application's authorization boundary and makes every downstream role check less trustworthy.

**Recommended fix:** Remove `:role` from public signup parameters and assign a safe default role server-side, typically `attendee`. If elevated roles are required, create a separate privileged provisioning flow.

## 6. Core business relationships are not protected by database constraints

- **File / Line:** `db/schema.rb:17-83`
- **Category:** Data Integrity
- **Severity:** High

Critical foreign keys such as `events.user_id`, `orders.user_id`, `orders.event_id`, `order_items.order_id`, and `ticket_tiers.event_id` are nullable, and the schema does not show database-level foreign key constraints for these relationships. That leaves the system vulnerable to orphaned or invalid records created by bugs, scripts, jobs, or partial failures.

**Recommended fix:** Add `null: false` constraints, foreign keys, and essential uniqueness constraints in migrations for business-critical relationships. Keep model validations, but enforce core integrity rules at the database layer as well.

## 7. The test suite misses the highest-risk authorization and abuse cases

- **File / Line:** `spec/controllers/orders_controller_spec.rb:14-44`, `spec/controllers/events_controller_spec.rb:44-63`
- **Category:** Testing
- **Severity:** Medium

The request specs currently verify happy-path success for authenticated users, but they do not cover cross-user access, ownership checks, role restrictions, or malicious input. As a result, the most severe security regressions in the app are not protected by automated tests.

**Recommended fix:** Add negative request specs for non-owner access, attendee-versus-organizer permissions, and unsafe input handling. Treat these regression tests as mandatory before shipping new API behavior.