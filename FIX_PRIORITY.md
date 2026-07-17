# Fix Priority Guide

**Document Date:** July 18, 2026  
**Project:** KasirApp  
**Purpose:** Prioritized list of all fixes required for commercial launch

---

## Executive Summary

This document provides a prioritized list of all fixes required to make KasirApp commercially ready. Fixes are categorized by priority (Critical, High, Medium, Low) and include estimated effort and dependencies.

**Total Fixes:** 43  
**Critical:** 8  
**High:** 15  
**Medium:** 15  
**Low:** 5

**Total Estimated Effort:** 6-8 weeks

---

## Priority Levels

### CRITICAL (Must Fix Before Launch)
- Blocks deployment or authentication
- Security vulnerability
- Legal compliance risk
- Data loss risk

### HIGH (Should Fix Before Launch)
- Significant user experience impact
- Operational requirement
- Important security improvement
- Data integrity issue

### MEDIUM (Nice to Have Before Launch)
- Improves user experience
- Performance improvement
- Minor security improvement
- Operational enhancement

### LOW (Can Defer)
- Nice to have feature
- Minor improvement
- Enhancement
- Polish

---

## CRITICAL PRIORITY FIXES

### 1. Fix RLS Recursion Risk
**Category:** Security  
**Effort:** 2-3 days  
**Dependency:** None  
**Impact:** Blocks authentication

**Description:** Replace direct profiles queries in RLS policies with SECURITY DEFINER functions.

**Files:**
- All RLS policy files
- DATABASE_UPGRADE_V2.sql
- supabase-rls-policies.sql

**Steps:**
1. Create is_admin() SECURITY DEFINER function
2. Create is_kasir() SECURITY DEFINER function
3. Replace all direct profiles queries
4. Apply to all tables with RLS
5. Test authentication flows

---

### 2. Consolidate Database Migrations
**Category:** Database  
**Effort:** 3-4 days  
**Dependency:** None  
**Impact:** Blocks deployment

**Description:** Consolidate 25 SQL migration files into single migration with version tracking.

**Files:**
- All 25 SQL migration files

**Steps:**
1. Create schema_migrations table
2. Consolidate all migrations into DATABASE_UPGRADE_V3.sql
3. Add version numbers
4. Add rollback procedures
5. Test on fresh database

---

### 3. Implement User Registration
**Category:** Authentication  
**Effort:** 2-3 days  
**Dependency:** Email verification  
**Impact:** Blocks user onboarding

**Description:** Create signup flow with email verification and role selection.

**Files:**
- Create: src/app/signup/page.tsx
- Modify: src/contexts/AuthContext.tsx

**Steps:**
1. Create signup page
2. Add signup form
3. Add email verification
4. Add role approval workflow
5. Test signup flow

---

### 4. Implement Password Reset
**Category:** Authentication  
**Effort:** 1-2 days  
**Dependency:** Email verification  
**Impact:** Blocks account recovery

**Description:** Create forgot password and reset password flows.

**Files:**
- Create: src/app/forgot-password/page.tsx
- Create: src/app/reset-password/page.tsx
- Modify: src/contexts/AuthContext.tsx

**Steps:**
1. Create forgot password page
2. Create reset password page
3. Implement password reset
4. Add password strength validation
5. Test password reset flow

---

### 5. Enable Email Verification
**Category:** Authentication  
**Effort:** 0.5-1 day  
**Dependency:** None  
**Impact:** Required for signup/reset

**Description:** Enable and enforce email verification in Supabase Auth.

**Files:**
- Supabase Dashboard
- src/contexts/AuthContext.tsx

**Steps:**
1. Enable email verification in Supabase
2. Add verification check in login
3. Add resend verification option
4. Block access until verified
5. Test email verification

---

### 6. Implement Rate Limiting
**Category:** Security  
**Effort:** 2-3 days  
**Dependency:** None  
**Impact:** Security vulnerability

**Description:** Implement rate limiting on authentication and API endpoints.

**Files:**
- src/lib/supabase.ts
- All API endpoints

**Steps:**
1. Implement rate limiting middleware
2. Apply to authentication endpoints
3. Apply to API endpoints
4. Add rate limit headers
5. Log violations
6. Test rate limiting

---

### 7. Add Receipt Generation
**Category:** POS  
**Effort:** 2-3 days  
**Dependency:** None  
**Impact:** Legal compliance

**Description:** Add receipt generation with thermal printer support.

**Files:**
- src/app/pos/page.tsx

**Steps:**
1. Create receipt template
2. Add receipt generation to checkout
3. Add thermal printer support
4. Add PDF download option
5. Add email receipt option
6. Test receipt generation

---

### 8. Add Server-Side Validation
**Category:** Security  
**Effort:** 2-3 days  
**Dependency:** None  
**Impact:** Security vulnerability

**Description:** Add server-side validation for all user inputs.

**Files:**
- All form components
- Create validation schemas

**Steps:**
1. Install Zod validation library
2. Create validation schemas
3. Add validation to all forms
4. Sanitize all input
5. Add database constraints
6. Test with malicious input

---

## HIGH PRIORITY FIXES

### 9. Add Database Version Tracking
**Category:** Database  
**Effort:** 1 day  
**Dependency:** Migration consolidation  
**Impact:** Deployment risk

**Description:** Add schema_migrations table to track applied migrations.

**Files:**
- DATABASE_UPGRADE_V3.sql

**Steps:**
1. Create schema_migrations table
2. Add migration version tracking
3. Add checksum validation
4. Add rollback tracking
5. Test version tracking

---

### 10. Fix Missing Foreign Keys
**Category:** Database  
**Effort:** 1 day  
**Dependency:** None  
**Impact:** Data integrity

**Description:** Ensure all foreign keys are properly enforced.

**Files:**
- atomic-checkout-migration.sql
- customers-migration.sql

**Steps:**
1. Remove conditional logic
2. Add proper foreign keys
3. Add ON DELETE CASCADE/SET NULL
4. Test referential integrity
5. Verify data consistency

---

### 11. Document Backup Strategy
**Category:** Operations  
**Effort:** 1 day  
**Dependency:** None  
**Impact:** Data loss risk

**Description:** Document backup and restore procedures.

**Files:**
- Create: BACKUP_STRATEGY.md

**Steps:**
1. Document backup configuration
2. Document restore procedure
3. Test backup restoration
4. Document backup monitoring
5. Create backup schedule

---

### 12. Add Audit Logging
**Category:** Security  
**Effort:** 3-4 days  
**Dependency:** None  
**Impact:** Compliance risk

**Description:** Implement audit logging for all sensitive operations.

**Files:**
- Create: audit_logs table
- All sensitive operations

**Steps:**
1. Create audit_logs table
2. Log authentication events
3. Log data modifications
4. Log role changes
5. Add audit log viewer
6. Test audit logging

---

### 13. Implement Shift Management
**Category:** Business Logic  
**Effort:** 2-3 days  
**Dependency:** None  
**Impact:** Operational requirement

**Description:** Implement shift opening/closing workflow.

**Files:**
- Create: src/app/shifts/page.tsx
- Create: shifts table

**Steps:**
1. Create shifts table
2. Create shift opening flow
3. Create shift closing flow
4. Add shift summary
5. Test shift management

---

### 14. Implement Cash Reconciliation
**Category:** Business Logic  
**Effort:** 2-3 days  
**Dependency:** Shift management  
**Impact:** Operational requirement

**Description:** Implement cash reconciliation workflow.

**Files:**
- Create: src/app/reconciliation/page.tsx
- Create: cash_drawer table

**Steps:**
1. Create cash_drawer table
2. Create reconciliation flow
3. Add variance tracking
4. Add approval workflow
5. Test reconciliation

---

### 15. Add Performance Monitoring
**Category:** Performance  
**Effort:** 2-3 days  
**Dependency:** None  
**Impact:** Observability

**Description:** Add performance monitoring and alerting.

**Files:**
- Vercel Analytics
- Supabase Logs

**Steps:**
1. Add Vercel Analytics
2. Enable Supabase query logging
3. Set up performance dashboards
4. Configure alerting
5. Document baselines

---

### 16. Add Query Optimization
**Category:** Performance  
**Effort:** 2-3 days  
**Dependency:** Performance monitoring  
**Impact:** Database performance

**Description:** Analyze and optimize slow queries.

**Files:**
- All Supabase queries

**Steps:**
1. Enable query logging
2. Analyze slow queries
3. Add composite indexes
4. Optimize N+1 queries
5. Test query performance

---

### 17. Implement Caching Strategy
**Category:** Performance  
**Effort:** 2-3 days  
**Dependency:** None  
**Impact:** Performance

**Description:** Implement caching for frequently accessed data.

**Files:**
- Install React Query or SWR
- All data fetching

**Steps:**
1. Install caching library
2. Cache static data
3. Implement cache invalidation
4. Add CDN caching
5. Test caching effectiveness

---

### 18. Replace Alerts with Toasts
**Category:** UI/UX  
**Effort:** 1-2 days  
**Dependency:** None  
**Impact:** User experience

**Description:** Replace all alert() calls with toast notifications.

**Files:**
- src/app/pos/page.tsx
- src/app/inventory/products/page.tsx
- All other pages with alerts

**Steps:**
1. Install toast library
2. Replace all alerts
3. Add toast variants
4. Test all error flows
5. Verify consistent styling

---

### 19. Add Loading States
**Category:** UI/UX  
**Effort:** 2-3 days  
**Dependency:** None  
**Impact:** User experience

**Description:** Add consistent loading states to all async operations.

**Files:**
- All pages with async operations

**Steps:**
1. Implement loading state pattern
2. Add loading indicators
3. Disable buttons during loading
4. Add skeleton loaders
5. Test all loading states

---

### 20. Add Environment Variable Validation
**Category:** Configuration  
**Effort:** 0.5-1 day  
**Dependency:** None  
**Impact:** Configuration risk

**Description:** Validate environment variables at startup.

**Files:**
- src/lib/supabase.ts
- Create: src/lib/env.ts

**Steps:**
1. Create validation function
2. Validate all required variables
3. Add clear error messages
4. Add type safety
5. Test with invalid config

---

### 21. Add Void/Refund Flow
**Category:** POS  
**Effort:** 2-3 days  
**Dependency:** None  
**Impact:** Business requirement

**Description:** Implement void and refund functionality.

**Files:**
- Create: src/app/void/page.tsx
- Create: void_transactions table

**Steps:**
1. Create void_transactions table
2. Create void flow
3. Add approval workflow
4. Add refund flow
5. Test void/refund

---

### 22. Add Privacy Policy
**Category:** Compliance  
**Effort:** 1 day  
**Dependency:** None  
**Impact:** Legal compliance

**Description:** Create privacy policy page.

**Files:**
- Create: src/app/privacy/page.tsx

**Steps:**
1. Draft privacy policy
2. Create privacy page
3. Add link to footer
4. Review with legal
5. Publish policy

---

### 23. Add Terms of Service
**Category:** Compliance  
**Effort:** 1 day  
**Dependency:** None  
**Impact:** Legal compliance

**Description:** Create terms of service page.

**Files:**
- Create: src/app/terms/page.tsx

**Steps:**
1. Draft terms of service
2. Create terms page
3. Add link to footer
4. Review with legal
5. Publish terms

---

## MEDIUM PRIORITY FIXES

### 24. Improve Empty States
**Category:** UI/UX  
**Effort:** 2-3 days  
**Dependency:** None  
**Impact:** User experience

**Description:** Design helpful empty states with illustrations.

**Files:**
- All pages with empty states

**Steps:**
1. Design empty state components
2. Add illustrations
3. Add call-to-action buttons
4. Add descriptive text
5. Test all empty states

---

### 25. Wrap Pages with ErrorBoundary
**Category:** Error Handling  
**Effort:** 1 day  
**Dependency:** None  
**Impact:** Error recovery

**Description:** Wrap all pages with ErrorBoundary component.

**Files:**
- All page components

**Steps:**
1. Update ErrorBoundary with logging
2. Wrap all pages
3. Add error messages
4. Add recovery options
5. Test error scenarios

---

### 26. Add Composite Indexes
**Category:** Performance  
**Effort:** 0.5 day  
**Dependency:** None  
**Impact:** Query performance

**Description:** Add composite indexes for common query patterns.

**Files:**
- DATABASE_UPGRADE_V3.sql

**Steps:**
1. Identify query patterns
2. Add composite indexes
3. Test query performance
4. Monitor index usage

---

### 27. Add Data Validation Constraints
**Category:** Database  
**Effort:** 0.5 day  
**Dependency:** None  
**Impact:** Data quality

**Description:** Add CHECK constraints for business rules.

**Files:**
- DATABASE_UPGRADE_V3.sql

**Steps:**
1. Identify business rules
2. Add CHECK constraints
3. Test constraints
4. Document constraints

---

### 28. Optimize Touch Targets
**Category:** Mobile UX  
**Effort:** 1-2 days  
**Dependency:** None  
**Impact:** Mobile experience

**Description:** Ensure all touch targets are 44px minimum.

**Files:**
- All interactive components

**Steps:**
1. Audit touch targets
2. Increase button sizes
3. Add padding
4. Test on mobile
5. Verify accessibility

---

### 29. Add Image Optimization
**Category:** Performance  
**Effort:** 1-2 days  
**Dependency:** None  
**Impact**: Image performance

**Description:** Use Next.js Image component for optimization.

**Files:**
- Product images

**Steps:**
1. Replace img with Image
2. Configure optimization
3. Implement lazy loading
4. Test image performance

---

### 30. Implement Code Splitting
**Category:** Performance  
**Effort:** 1-2 days  
**Dependency:** None  
**Impact**: Bundle size

**Description:** Implement dynamic imports for large components.

**Files:**
- Large components

**Steps:**
1. Identify large components
2. Implement dynamic imports
3. Analyze bundle size
4. Test performance

---

### 31. Add CSRF Protection
**Category:** Security  
**Effort:** 1-2 days  
**Dependency:** None  
**Impact**: Security

**Description:** Implement CSRF tokens for state-changing operations.

**Files:**
- All forms

**Steps:**
1. Implement CSRF tokens
2. Validate tokens
3. Add SameSite cookies
4. Test CSRF protection

---

### 32. Add CSP
**Category:** Security  
**Effort:** 0.5-1 day  
**Dependency:** None  
**Impact**: Security

**Description:** Implement Content Security Policy.

**Files:**
- src/app/layout.tsx
- next.config.js

**Steps:**
1. Implement CSP header
2. Use strict policy
3. Add nonce for scripts
4. Test CSP compliance

---

### 33. Add Password Policy
**Category:** Security  
**Effort:** 1 day  
**Dependency:** None  
**Impact**: Security

**Description:** Enforce strong password policy.

**Files:**
- Authentication flows

**Steps:**
1. Implement password policy
2. Add strength indicator
3. Implement password history
4. Test password policy

---

### 34. Add Account Lockout
**Category:** Security  
**Effort:** 1-2 days  
**Dependency:** None  
**Impact**: Security

**Description:** Implement account lockout after failed attempts.

**Files:**
- Authentication flows

**Steps:**
1. Implement lockout logic
2. Track failed attempts
3. Add email notification
4. Test lockout

---

### 35. Add Session Refresh
**Category:** Authentication  
**Effort:** 0.5-1 day  
**Dependency:** None  
**Impact**: User experience

**Description:** Implement automatic session refresh.

**Files:**
- src/contexts/AuthContext.tsx

**Steps:**
1. Implement refresh interval
2. Add expiry warning
3. Add "stay logged in" option
4. Test session refresh

---

### 36. Add Swipe Gestures
**Category:** Mobile UX  
**Effort:** 1-2 days  
**Dependency:** None  
**Impact**: Mobile experience

**Description:** Implement swipe gestures for navigation.

**Files:**
- src/components/MobileNavigation.tsx

**Steps:**
1. Implement swipe gestures
2. Add swipe to go back
3. Add swipe to switch tabs
4. Test gestures

---

### 37. Add 2FA
**Category:** Security  
**Effort:** 3-4 days  
**Dependency:** None  
**Impact**: Security

**Description**: Add multi-factor authentication for admin accounts.

**Files:**
- Create: src/app/2fa/page.tsx

**Steps:**
1. Add TOTP support
2. Create 2FA setup page
3. Add 2FA verification
4. Add backup codes
5. Test 2FA flow

---

### 38. Write Deployment Guide
**Category:** Documentation  
**Effort:** 1 day  
**Dependency:** None  
**Impact**: Operations

**Description:** Create comprehensive deployment guide.

**Files:**
- Create: DEPLOYMENT_GUIDE.md

**Steps:**
1. Document deployment steps
2. Document environment setup
3. Document troubleshooting
4. Test deployment guide

---

## LOW PRIORITY FIXES

### 39. Add HTTPS Enforcement
**Category:** Security  
**Effort:** 0.5 day  
**Dependency:** None  
**Impact**: Security

**Description:** Enforce HTTPS and add HSTS header.

**Files:**
- next.config.js
- Vercel config

**Steps:**
1. Enforce HTTPS in Vercel
2. Add HSTS header
3. Test HTTPS enforcement

---

### 40. Add Lazy Loading
**Category:** Performance  
**Effort:** 1-2 days  
**Dependency:** None  
**Impact**: Performance

**Description:** Implement lazy loading for below-fold components.

**Files:**
- All pages

**Steps:**
1. Implement lazy loading
2. Add intersection observer
3. Add skeleton states
4. Test lazy loading

---

### 41. Add Bundle Monitoring
**Category:** Performance  
**Effort:** 1 day  
**Dependency:** None  
**Impact**: Build optimization

**Description:** Monitor bundle size in CI/CD.

**Files:**
- package.json
- CI/CD config

**Steps:**
1. Add bundle analyzer
2. Set bundle budgets
3. Monitor in CI/CD
4. Optimize bundle

---

### 42. Write User Manual
**Category:** Documentation  
**Effort:** 1-2 days  
**Dependency:** None  
**Impact**: User support

**Description:** Create comprehensive user manual.

**Files:**
- Create: USER_MANUAL.md

**Steps:**
1. Document all features
2. Add screenshots
3. Add troubleshooting
4. Review manual

---

### 43. Write Admin Guide
**Category:** Documentation  
**Effort:** 1-2 days  
**Dependency:** None  
**Impact**: Admin support

**Description:** Create comprehensive admin guide.

**Files:**
- Create: ADMIN_GUIDE.md

**Steps:**
1. Document admin features
2. Add best practices
3. Add troubleshooting
4. Review guide

---

## Fix Summary

### By Priority
- **Critical:** 8 fixes (14-21 days)
- **High:** 15 fixes (20-28 days)
- **Medium:** 15 fixes (15-23 days)
- **Low:** 5 fixes (5-8 days)

**Total:** 43 fixes (54-80 days = 8-12 weeks)

### By Category
- **Security:** 10 fixes (15-22 days)
- **Database:** 5 fixes (6-8 days)
- **Authentication:** 5 fixes (6-9 days)
- **Performance:** 7 fixes (10-15 days)
- **UI/UX:** 6 fixes (8-13 days)
- **Business Logic:** 4 fixes (6-9 days)
- **Operations:** 3 fixes (4-5 days)
- **Documentation:** 3 fixes (4-6 days)

---

## Recommended Fix Order

### Phase 1: Critical Fixes (Weeks 1-2)
1. Fix RLS Recursion (2-3 days)
2. Consolidate Migrations (3-4 days)
3. Enable Email Verification (0.5-1 day)
4. Implement Rate Limiting (2-3 days)

### Phase 2: Authentication Fixes (Weeks 2-3)
5. Implement User Registration (2-3 days)
6. Implement Password Reset (1-2 days)
7. Add Server-Side Validation (2-3 days)

### Phase 3: Business Features (Weeks 3-4)
8. Add Receipt Generation (2-3 days)
9. Add Void/Refund Flow (2-3 days)
10. Implement Shift Management (2-3 days)

### Phase 4: Security & Performance (Weeks 4-5)
11. Add Audit Logging (3-4 days)
12. Add Performance Monitoring (2-3 days)
13. Add Query Optimization (2-3 days)

### Phase 5: Operations & Compliance (Weeks 5-6)
14. Implement Cash Reconciliation (2-3 days)
15. Document Backup Strategy (1 day)
16. Add Privacy Policy (1 day)
17. Add Terms of Service (1 day)

### Phase 6: UI/UX Improvements (Weeks 6-7)
18. Replace Alerts with Toasts (1-2 days)
19. Add Loading States (2-3 days)
20. Improve Empty States (2-3 days)

### Phase 7: Polish & Documentation (Weeks 7-8)
21. Wrap Pages with ErrorBoundary (1 day)
22. Write Deployment Guide (1 day)
23. Write User Manual (1-2 days)
24. Write Admin Guide (1-2 days)

**Total: 8 weeks**

---

## Dependencies

### Critical Dependencies
- User Registration depends on Email Verification
- Password Reset depends on Email Verification
- Cash Reconciliation depends on Shift Management

### Recommended Dependencies
- Query Optimization depends on Performance Monitoring
- Caching can be done independently
- All UI/UX fixes are independent

---

## Risk Assessment

### High Risk Fixes
1. Migration Consolidation - Risk of data loss
2. RLS Recursion Fix - Risk of authentication breakage
3. Server-Side Validation - Risk of breaking existing flows

### Medium Risk Fixes
1. Rate Limiting - Risk of blocking legitimate users
2. Audit Logging - Risk of performance impact
3. Performance Monitoring - Risk of overhead

### Low Risk Fixes
1. UI/UX improvements - Low risk
2. Documentation - No risk
3. Polish features - Low risk

---

**Document Completed:** July 18, 2026  
**Next Review:** After Phase 1 completion
