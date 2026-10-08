# Offline POS System

Modern, offline-first retail POS built with Flutter. Optimized for desktop (Windows/macOS) with responsive layouts for tablet/mobile.

## Status
- Dashboard sales analytics (charts) removed from the dashboard UI
- Dashboard stats cards visibility controlled by Settings → `hide_stats_cards`
- Desktop sidebar is permanently expanded (collapse disabled)

## Key Features
- POS and Sales
  - Quick navigation to POS, Sales, Products, Customers
  - Speed Dial actions: New Sale, Purchase Invoice, Add Product, Add Customer
  - Keyboard shortcuts (via `KeyboardShortcutWrapper`) for faster workflows

- Dashboard
  - Stats cards for Today’s Sales, Total Orders, Customers, Products
  - Cards respect the `hide_stats_cards` setting
  - Modern app bar with business name, clock, weather, dark mode toggle
  - Quick Access grid to frequent modules

- Navigation
  - Desktop: permanently expanded sidebar with role-aware items
  - Tablet: `NavigationRail` with labels always visible
  - Mobile: bottom navigation

- Theming & UX
  - Light/Dark mode toggle
  - Responsive, touch-friendly components

- Offline & Data
  - Database access via `databaseServiceProvider`
  - Cached queries for sales stats to reduce DB calls

## Recent Changes
- Removed Sales Analytics charts from `Dashboard`
- Added conditional rendering for stats cards based on `hide_stats_cards`
- Disabled sidebar collapse; removed toggle buttons in desktop sidebar

## Settings Reference
- `hide_stats_cards`: when set to `'true'`, dashboard stats cards are hidden.

## Business Nature Support

This POS system supports multiple business natures:
- Mobile Phone Shop
- Restaurant/Cafe
- **Salon / Hairdresser** ⭐

### Salon / Hairdresser Business Nature

The system includes comprehensive features specifically for salon/hairdresser businesses:
- Service-based product management
- Employee commission tracking
- Salon-specific reports and analytics
- Simplified navigation (hides irrelevant features)

**📖 See [SALON_BUSINESS_NATURE_DOCUMENTATION.md](./SALON_BUSINESS_NATURE_DOCUMENTATION.md) for complete documentation of all salon-specific features.**

**Important**: All salon features are exclusive to the "salon" business nature and do not affect other business types.

## Project Structure (high-level)
- `lib/router/app_router.dart`: Routes, navigation shells, desktop/tablet/mobile layouts
- `lib/screens/dashboard_screen.dart`: Dashboard UI (stats cards, quick access, app bar)
- `lib/screens/pos_screen.dart`: POS screen
- `lib/providers/*`: Riverpod providers (auth, theme, sales, currency, products)
- `lib/services/*`: Data services (database, global refresh)

## Development
Prerequisites:
- Flutter 3.x

Run:
```bash
flutter pub get
flutter run -d macos # or windows, chrome, etc.
```

## Windows release

Every push to `main` runs the Windows Release workflow. After it succeeds,
download the `RetailPOS-Windows-x64` artifact from GitHub Actions and extract
the complete ZIP before running `RetailPOS.exe`. The DLL and `data` files in
the archive are required by the application.

Creating and pushing a version tag such as `v1.0.0` also publishes the same
ZIP on the repository's GitHub Releases page.

## Roadmap (Retailer-focused)
- Quick selling: barcode/weighted barcodes, quick keys/favorites
- Discounts & promotions: line/cart level, coupons, manager override
- Payments: split/partial payments, rounding/surcharges, tips, multi-currency
- Customer & loyalty: quick add/search, loyalty points, store credit
- Inventory: real-time stock checks, variants/IMEI/serials, expiries
- Returns/exchanges: receipt lookup, exchange flow, refund methods
- Receipts: customizable thermal template, email/SMS/QR e-receipts
- Cash management: drawer open/close, blind drops, Z/X reports
- Hardware: printer/cash drawer/scanner/scale/customer display integrations
- Security & audit: role permissions, offline queue/sync, audit log

## Notes
- If your settings key differs from `hide_stats_cards`, update `DashboardScreen._loadStatsCardsVisibility()` accordingly.

## Bulk Product Add (Excel Import)
- Open `Products` screen.
- Use the top-right `Bulk actions` menu.
- Choose:
  - `Bulk Add Products` to import `.xlsx`/`.xls`
  - `Bulk Import Guide` to see required headers and sample rows in-app

Required header order:
`Name, Category, Retail Cash, Cost Price, Stock, Barcode, Unit, Reorder Level, Reorder Quantity, Discount, Tax, Description`

Rules:
- `Name` and `Category` are required.
- If `Barcode` matches an existing product, the product is updated.
- If barcode is empty, the importer tries update by `Name + Category`; otherwise inserts.

Sample file:
- `docs/product_bulk_import_sample.csv`
