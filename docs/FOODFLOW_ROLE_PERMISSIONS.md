# FoodFlow Role Permissions (RBAC Matrix)

| Endpoint Group | CUSTOMER | RESTAURANT_OWNER | DELIVERY_PARTNER | ADMIN |
| :--- | :---: | :---: | :---: | :---: |
| `/auth/*` | ✅ | ✅ | ✅ | ✅ |
| `/restaurants/*` | ✅ | ✅ | ✅ | ✅ |
| `/cart/*` | ✅ | ❌ | ❌ | ✅ |
| `/orders` (Create & View Own) | ✅ | ❌ | ❌ | ✅ |
| `/users/addresses` | ✅ | ❌ | ❌ | ✅ |
| `/reviews` | ✅ | ❌ | ❌ | ✅ |
| `/owner/*` (Menu & Owner Orders) | ❌ | ✅ | ❌ | ✅ |
| `/delivery/*` (Delivery Assignments) | ❌ | ❌ | ✅ | ✅ |
| `/admin/*` (System Metrics & Approvals) | ❌ | ❌ | ❌ | ✅ |

> [!IMPORTANT]
> Backend authorization dependencies (`require_customer`, `require_restaurant_owner`, `require_delivery_partner`, `require_admin`) enforce this matrix on every request.
