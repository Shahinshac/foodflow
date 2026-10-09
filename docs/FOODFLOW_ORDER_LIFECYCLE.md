# FoodFlow Authoritative Order Lifecycle

## Order State Machine Diagram

```
CUSTOMER PLACES ORDER
        │
        ▼
   [PLACED] ─── (Payment Pending) ───► [PAYMENT_PENDING]
        │                                     │
        ▼                                     ▼
[RESTAURANT_CONFIRMED] ◄────── (Success) ─── [PAYMENT_SUCCESS]
        │
        ▼
   [PREPARING]
        │
        ▼
[READY_FOR_PICKUP]
        │
        ▼
[DELIVERY_PARTNER_ASSIGNED]
        │
        ▼
[DELIVERY_PARTNER_AT_RESTAURANT]
        │
        ▼
   [PICKED_UP]
        │
        ▼
 [OUT_FOR_DELIVERY]
        │
        ▼
  [NEAR_CUSTOMER]
        │
        ▼
   [DELIVERED] ───► CUSTOMER REVIEWS RESTAURANT/ORDER
```

## State Machine Rules
1. **Server-Side Enforcement:** Transition rules are validated by the backend. Invalid state transitions (e.g. `DELIVERED -> PREPARING` or `REJECTED -> CONFIRMED`) are rejected with `HTTP 400 Bad Request`.
2. **Audit History Log:** Every status change inserts a record into `order_status_history` capturing `status`, `previous_status`, `changed_at`, `changed_by_user_id`, `actor_role`, and `reason`.
3. **Payout Trigger:** Transitioning an order to `DELIVERED` automatically updates delivery partner total earnings and marks payment as `COMPLETED`.
