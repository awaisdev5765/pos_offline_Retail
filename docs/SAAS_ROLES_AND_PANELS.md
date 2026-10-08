# SaaS Owner vs Restaurant Admin vs POS – Roles & Panels

This document explains how to distinguish **SaaS owner**, **Restaurant admin**, and **POS (mobile/web)** users, and how each gets a separate login and panel.

---

## 1. The three user types

| User type          | Who they are                    | Login                      | Panel / App                    |
|--------------------|----------------------------------|----------------------------|--------------------------------|
| **SaaS owner**     | Platform owner (you/your company)| Separate SaaS admin login  | SaaS admin panel (web)         |
| **Restaurant admin** | Owner/manager of one restaurant | Restaurant admin login    | Restaurant admin panel (web)   |
| **POS user**       | Staff/cashier at a restaurant    | POS login (current app)    | Mobile POS or Web POS (this app) |

---

## 2. How to distinguish them

### By **user type** (and optional **tenant**)

- **User type** (or account type): `saas_owner` | `restaurant_admin` | `pos_user`
- **Tenant**: which restaurant (or “no tenant” for SaaS owner).

Conceptually:

```
SaaS owner       → user_type = saas_owner,   tenant_id = null
Restaurant admin → user_type = restaurant_admin, tenant_id = <restaurant_id>
POS user         → user_type = pos_user,      tenant_id = <restaurant_id>
```

So:

- **SaaS owner**: separate login + panel; no single restaurant; manages all restaurants.
- **Restaurant admin**: separate login + panel; tied to one restaurant; manages that restaurant (menu, staff, reports, settings).
- **POS user**: same as today – staff/cashier; login in this app; sees POS + limited nav by role (admin/manager/cashier/staff).

---

## 3. Recommended architecture

### Option A – Same backend, different entry points (recommended)

- **One backend API** with:
  - Tenants (restaurants)
  - Users with: `user_type` (saas_owner | restaurant_admin | pos_user), `tenant_id`, and existing roles (admin/manager/cashier/staff) for POS users only.
- **Three entry points**:
  1. **SaaS owner panel** (e.g. `admin.yoursaas.com`) – separate web app (React/Next.js/Flutter Web).
  2. **Restaurant admin panel** (e.g. `app.yoursaas.com` or `restaurant.yoursaas.com`) – web app for restaurant admins.
  3. **POS** – this Flutter app (mobile + web) used only by **POS users** (staff/cashier).

So:

- **SaaS owner** → separate login and panel (SaaS admin app).
- **Restaurant admin** → separate login and panel (restaurant admin app).
- **POS** → current login and panel (this app); no SaaS owner or restaurant admin UI here.

### Option B – All in one app (single codebase)

- One web app with **one login** that:
  - Sends credentials to backend.
  - Backend returns `user_type` (+ `tenant_id`).
  - App **redirects** after login:
    - `saas_owner` → SaaS admin panel (routes like `/saas/*`).
    - `restaurant_admin` → Restaurant admin panel (e.g. `/restaurant/*`).
    - `pos_user` → POS panel (e.g. `/pos` or `/`).
- Mobile app can stay POS-only (only `pos_user` login).

---

## 4. What to add in the backend (when you have one)

- **Tenants table**: e.g. `id`, `name`, `slug`, `plan`, `created_at`.
- **Users table** (or extend existing):
  - `user_type`: `saas_owner` | `restaurant_admin` | `pos_user`
  - `tenant_id`: nullable; null for SaaS owner, set for restaurant admin and POS user.
- **Auth response** after login should include:
  - `user_type`
  - `tenant_id` (and maybe `tenant_name` for UI)
  - For POS: existing employee/role (admin/manager/cashier/staff) and permissions.

So:

- **SaaS owner** → `user_type=saas_owner`, `tenant_id=null` → show SaaS panel.
- **Restaurant admin** → `user_type=restaurant_admin`, `tenant_id=<id>` → show restaurant admin panel for that tenant.
- **POS user** → `user_type=pos_user`, `tenant_id=<id>` → open POS app and load data for that tenant.

---

## 5. What to do in this POS app (current Flutter app)

This app should stay **POS-only**:

- **Login**: Only for **POS users** (staff/cashier). Optionally:
  - If you later use a shared backend, login API returns `user_type`; if `user_type` is not `pos_user`, show “Use the restaurant admin / SaaS admin website” and do not log in.
- **No SaaS owner UI** in this app – SaaS owner uses a separate panel (separate app).
- **No restaurant admin UI** in this app – restaurant admin uses a separate panel (separate app).
- **Restaurant context**: When you add a backend, add something like `tenant_id` (or `restaurant_id`) in auth state so every API call from this app is scoped to that restaurant.

So:

- **SaaS owner** = separate login + panel (different app).
- **Restaurant admin** = separate login + panel (different app).
- **Mobile POS / Web POS** = this app; one login; panel = current dashboard + POS + permissions.

---

## 6. Summary table

| Role               | Separate login? | Separate panel?        | Where is it?                    |
|--------------------|----------------|------------------------|---------------------------------|
| **SaaS owner**     | Yes            | Yes (SaaS admin panel) | Separate web app (e.g. admin.*) |
| **Restaurant admin** | Yes          | Yes (restaurant panel)| Separate web app (e.g. app.*)    |
| **POS (mobile/web)** | Yes (POS login) | Yes (POS panel)     | This Flutter app                |

You distinguish them by **user_type** (+ **tenant_id**) from the backend; each type has its own login and panel as above.

---

## 7. Next steps (when you add a backend)

1. **Backend**: Add tenants (restaurants), users, and auth API that returns `user_type` and `tenant_id`.
2. **SaaS admin app**: New web app for SaaS owner (e.g. React/Next.js) at `admin.yoursaas.com` – only accepts `user_type === 'saas_owner'`.
3. **Restaurant admin app**: New web app for restaurant admins at `app.yoursaas.com` – only accepts `user_type === 'restaurant_admin'`.
4. **This POS app**: Keep as-is for POS only. When you switch to API login, read `user_type` from response; if not `pos_user`, show a message like “Please use the Restaurant Admin or SaaS Admin website” and do not log in. Store `tenant_id` in auth state and send it with every API request.
