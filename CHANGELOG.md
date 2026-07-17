# KasirApp Changelog

All notable changes to KasirApp will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [Unreleased]

### Added
- Form validation to prevent negative values in products form
- Form validation to prevent negative values in expenses form  
- Form validation to prevent negative values in stock-in form
- Validation messages for invalid user inputs

### Changed
- Dashboard date calculation from UTC to local timezone for Indonesian users
- Stock-in page to fetch current stock from database before update
- Error handling to throw errors instead of console logging
- All console.log and console.error statements removed from production code

### Fixed
- **QA-001:** Removed all debug console statements from production code
- **QA-002:** Fixed stock-in stale data issue by fetching current database values
- **QA-004:** Fixed dashboard timezone to use local time instead of UTC
- **QA-006:** Added form validation to prevent negative/invalid values

### Security
- Removed debug console statements that could expose sensitive information
- Improved error handling to use ErrorBoundary component

### Performance
- Reduced console logging overhead
- Improved data integrity by avoiding stale data

---

## [0.9.0] - 2026-07-16

### Added
- Full POS system with cart management
- Product inventory management
- Recipe-based HPP calculation
- Raw materials tracking
- Stock movement tracking
- Sales transaction management
- Expense tracking
- Dashboard with real-time statistics
- Reports with PDF and Excel export
- User authentication with role-based access
- Settings management (categories, payment methods, general)
- Mobile-responsive design
- PWA support

### Technical
- Next.js 14 with App Router
- TypeScript for type safety
- TailwindCSS for styling
- shadcn/ui components
- Zustand for state management
- Supabase for backend (PostgreSQL with RLS)
- date-fns for date handling
- jsPDF for PDF generation
- xlsx for Excel export

---

## [0.8.0] - Previous Release

### Added
- Initial POS functionality
- Basic product management
- Simple sales tracking
- Authentication system

---

## Version History

### Version 0.9.0
- Current development version
- Focus on stabilization and bug fixes
- Preparing for commercial release

### Version 0.8.0
- Initial MVP release
- Core POS functionality
- Basic inventory management

---

## Upcoming Features (Version 1.0)

### Planned
- Customer management system
- Supplier management
- Barcode scanning support
- Receipt and invoice customization
- Discount system
- Tax calculation
- Store profile and branding
- Backup and restore functionality
- Import/export for products
- Low stock notifications
- Toast notifications (replacing browser alerts)
- Loading states for all forms
- Error recovery mechanism
- Transactional stock updates

---

## Breaking Changes

None in current release.

---

## Migration Guide

No database migrations required for current changes.

---

## Contributors

- Cascade AI Assistant (CTO)
- Development Team

---

## License

Proprietary - KasirApp Commercial License
