# KasirApp Version 1.0 - Rollback Plan

**Purpose:** Exact procedures to rollback failed deployment  
**Version:** 1.0.0  
**Last Updated:** July 17, 2026  
**Status:** READY

---

## Rollback Triggers

### Immediate Rollback (Stop Deployment)

Trigger rollback immediately if:
- Migration fails with error
- Database backup fails
- Frontend deployment fails
- Critical error in smoke tests
- Data corruption detected
- Security vulnerability discovered

### Post-Deployment Rollback (Within 1 Hour)

Trigger rollback within 1 hour if:
- Transaction failure rate >5%
- Data corruption detected
- Critical performance degradation (>50%)
- Security vulnerability discovered
- Financial loss detected

---

## Rollback Decision Matrix

| Condition | Rollback Type | Time to Execute | Data Loss Risk |
|-----------|---------------|-----------------|----------------|
| Migration error | Database only | 5 minutes | None |
- Frontend error | Frontend only | 3 minutes | None
- Data corruption | Full rollback | 10 minutes | Minimal (since backup)
- Performance issue | Frontend only | 3 minutes | None
- Security issue | Full rollback | 10 minutes | None |

---

## Database Rollback Procedure

### Pre-Rollback Checks

**Owner:** Database Administrator  
**Duration:** 2 minutes

- [ ] Confirm rollback trigger condition
- [ ] Document current state
- [ ] Notify team of rollback
- [ ] Stop all application traffic
- [ ] Verify backup is available

### Step 1: Stop Application Traffic

**Owner:** DevOps Engineer  
**Duration:** 1 minute

- [ ] Put maintenance page up
- [ ] Stop accepting new transactions
- [ ] Verify no active transactions
- [ ] Document stop time

**Commands:**
```bash
# Put maintenance page up (Vercel)
vercel alias set your-domain.com maintenance.your-domain.com

# Or update next.config.js to redirect to maintenance page
```

### Step 2: Drop RPC Function

**Owner:** Database Administrator  
**Duration:** 1 minute

- [ ] Drop process_checkout function
- [ ] Verify function dropped
- [ ] Document function removal

**Commands:**
```sql
-- Drop RPC function
DROP FUNCTION IF EXISTS process_checkout CASCADE;

-- Verify function dropped
SELECT * FROM pg_proc WHERE proname = 'process_checkout';
-- Should return 0 rows
```

### Step 3: Drop Indexes

**Owner:** Database Administrator  
**Duration:** 1 minute

- [ ] Drop transaction_token index
- [ ] Drop customer_id index
- [ ] Drop discount_id index
- [ ] Verify indexes dropped
- [ ] Document index removal

**Commands:**
```sql
-- Drop indexes
DROP INDEX IF EXISTS idx_sales_transaction_token;
DROP INDEX IF EXISTS idx_sales_customer_id;
DROP INDEX IF EXISTS idx_sales_discount_id;

-- Verify indexes dropped
SELECT * FROM pg_indexes WHERE tablename = 'sales' AND indexname LIKE 'idx_sales_%';
-- Should return 0 rows
```

### Step 4: Drop Columns

**Owner:** Database Administrator  
**Duration:** 2 minutes

- [ ] Drop transaction_token column
- [ ] Drop tax_amount column
- [ ] Drop tax_rate column
- [ ] Drop discount_amount column
- [ ] Drop discount_id column
- [ ] Drop customer_id column
- [ ] Verify columns dropped
- [ ] Document column removal

**Commands:**
```sql
-- Drop columns (order matters due to dependencies)
ALTER TABLE sales DROP COLUMN IF EXISTS transaction_token;
ALTER TABLE sales DROP COLUMN IF EXISTS tax_amount;
ALTER TABLE sales DROP COLUMN IF EXISTS tax_rate;
ALTER TABLE sales DROP COLUMN IF EXISTS discount_amount;
ALTER TABLE sales DROP COLUMN IF EXISTS discount_id;
ALTER TABLE sales DROP COLUMN IF EXISTS customer_id;

-- Verify columns dropped
SELECT column_name 
FROM information_schema.columns 
WHERE table_name = 'sales' 
AND column_name IN ('transaction_token', 'tax_amount', 'tax_rate', 'discount_amount', 'discount_id', 'customer_id');
-- Should return 0 rows
```

### Step 5: Restore from Backup (If Needed)

**Owner:** Database Administrator  
**Duration:** 5 minutes

- [ ] Select appropriate backup point
- [ ] Initiate restore
- [ ] Monitor restore progress
- [ ] Verify restore completed
- [ ] Verify data integrity
- [ ] Document restore

**Commands:**
```sql
-- Restore via Supabase Dashboard
-- Or use pg_restore if available
```

**Important:**
- Only restore if column drop fails or data corruption detected
- Restore will lose all data since backup point
- Communicate data loss to stakeholders

### Step 6: Verify Database State

**Owner:** Database Administrator  
**Duration:** 2 minutes

- [ ] Verify sales table structure
- [ ] Verify no RPC function exists
- [ ] Verify no new indexes exist
- [ ] Verify no new columns exist
- [ ] Test basic queries
- [ ] Document verification

**Commands:**
```sql
-- Verify sales table structure
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_name = 'sales';

-- Verify no RPC function
SELECT * FROM pg_proc WHERE proname = 'process_checkout';

-- Verify no new indexes
SELECT * FROM pg_indexes WHERE tablename = 'sales' AND indexname LIKE 'idx_sales_%';

-- Test basic query
SELECT COUNT(*) FROM sales;
```

### Step 7: Restore Application Traffic

**Owner:** DevOps Engineer  
**Duration:** 1 minute

- [ ] Remove maintenance page
- [ ] Verify application loads
- [ ] Verify no console errors
- [ ] Verify API connectivity
- [ ] Document restore time

**Commands:**
```bash
# Remove maintenance page
vercel alias set your-domain.com production-url

# Or revert next.config.js
```

---

## Frontend Rollback Procedure

### Step 1: Revert Frontend Code

**Owner:** DevOps Engineer  
**Duration:** 2 minutes

- [ ] Identify previous deployment
- [ ] Revert to previous commit
- [ ] Deploy to production
- [ ] Verify deployment successful
- [ ] Document rollback

**Commands:**
```bash
# Revert to previous commit
git revert HEAD
git push origin main

# Or deploy specific previous commit
vercel --prod --prebuilt

# Or use Vercel dashboard to rollback
```

### Step 2: Clear Cache

**Owner:** DevOps Engineer  
**Duration:** 1 minute

- [ ] Clear Vercel cache
- [ ] Clear browser cache
- [ ] Verify cache cleared
- [ ] Document cache clear

**Commands:**
```bash
# Clear Vercel cache
vercel --force

# Or use Vercel dashboard
```

### Step 3: Verify Frontend

**Owner:** QA Engineer  
**Duration:** 2 minutes

- [ ] Verify application loads
- [ ] Verify login works
- [ ] Verify POS loads
- [ ] Verify no console errors
- [ ] Document verification

---

## Full Rollback Procedure

### Scenario: Complete Deployment Failure

**Duration:** 15 minutes

**Step 1: Stop Traffic (1 minute)**
- Put maintenance page up
- Stop accepting transactions

**Step 2: Database Rollback (5 minutes)**
- Drop RPC function
- Drop indexes
- Drop columns
- Verify database state

**Step 3: Frontend Rollback (3 minutes)**
- Revert frontend code
- Clear cache
- Verify frontend

**Step 4: Restore Backup (5 minutes)**
- Restore from backup
- Verify data integrity
- Test basic functionality

**Step 5: Restore Traffic (1 minute)**
- Remove maintenance page
- Verify application functional

---

## Data Validation After Rollback

### Critical Checks

**Owner:** QA Engineer  
**Duration:** 5 minutes

- [ ] Verify sales table structure
- [ ] Verify stock accuracy
- [ ] Verify profit accuracy
- [ ] Verify customer balances
- [ ] Verify no data corruption
- [ ] Run smoke tests

**Commands:**
```sql
-- Verify stock accuracy
SELECT p.id, p.name, p.stock,
  (SELECT COALESCE(SUM(CASE WHEN sm.type = 'in' THEN sm.quantity ELSE -sm.quantity END), 0)
   FROM stock_movements sm 
   WHERE sm.product_id = p.id) as calculated_stock
FROM products p
WHERE p.stock != calculated_stock;

-- Verify profit accuracy
SELECT s.id, s.profit,
  (SELECT COALESCE(SUM((si.price - si.cost) * si.quantity), 0)
   FROM sale_items si 
   WHERE si.sale_id = s.id) as calculated_profit
FROM sales s
WHERE s.profit != calculated_profit;

-- Verify no data corruption
SELECT COUNT(*) FROM sales WHERE total_amount < 0;
SELECT COUNT(*) FROM products WHERE stock < 0;
```

---

## Rollback Script

### Automated Database Rollback Script

Save as `rollback-atomic-checkout.sql`:

```sql
-- Rollback script for atomic-checkout-migration.sql
-- This script reverses the changes made by atomic-checkout-migration.sql
-- WARNING: This script will drop columns and lose data if new sales were created

BEGIN;

-- Drop RPC function
DROP FUNCTION IF EXISTS process_checkout CASCADE;

-- Drop indexes
DROP INDEX IF EXISTS idx_sales_transaction_token;
DROP INDEX IF EXISTS idx_sales_customer_id;
DROP INDEX IF EXISTS idx_sales_discount_id;

-- Drop columns (order matters due to dependencies)
ALTER TABLE sales DROP COLUMN IF EXISTS transaction_token;
ALTER TABLE sales DROP COLUMN IF EXISTS tax_amount;
ALTER TABLE sales DROP COLUMN IF EXISTS tax_rate;
ALTER TABLE sales DROP COLUMN IF EXISTS discount_amount;
ALTER TABLE sales DROP COLUMN IF EXISTS discount_id;
ALTER TABLE sales DROP COLUMN IF EXISTS customer_id;

COMMIT;

-- Verification queries
SELECT 'RPC function dropped' as status, COUNT(*) as count FROM pg_proc WHERE proname = 'process_checkout';
SELECT 'Indexes dropped' as status, COUNT(*) as count FROM pg_indexes WHERE tablename = 'sales' AND indexname LIKE 'idx_sales_%';
SELECT 'Columns dropped' as status, COUNT(*) as count FROM information_schema.columns WHERE table_name = 'sales' AND column_name IN ('transaction_token', 'tax_amount', 'tax_rate', 'discount_amount', 'discount_id', 'customer_id');
```

**Usage:**
```sql
-- Execute in Supabase SQL Editor
-- Or via command line
psql -h your-db.supabase.co -U postgres -d postgres -f rollback-atomic-checkout.sql
```

---

## Rollback Communication

### Internal Communication

**Notify Team:**
- Release Manager
- Database Administrator
- DevOps Engineer
- QA Engineer
- Development Team

**Communication Channels:**
- Slack/Discord
- Email
- Phone (if critical)

**Message Template:**
```
ROLLBACK INITIATED

Trigger: [trigger condition]
Time: [timestamp]
Owner: [name]

Rollback Type: [database/frontend/full]
Estimated Duration: [minutes]

Team Action Required:
- [specific actions]

Status Updates: [channel]
```

### External Communication

**Notify Stakeholders:**
- Product Owner
- Business Owner
- Support Team

**Communication Channels:**
- Email
- Phone (if critical)

**Message Template:**
```
DEPLOYMENT ROLLBACK

We are rolling back the KasirApp deployment due to [reason].

Impact:
- Application may be temporarily unavailable
- Data since [backup time] may be lost if full rollback required

Estimated Downtime: [minutes]

We will provide updates every [minutes].

Contact: [support contact]
```

---

## Rollback Verification

### Success Criteria

**Database Rollback Success:**
- [ ] RPC function dropped
- [ ] Indexes dropped
- [ ] Columns dropped
- [ ] Database structure verified
- [ ] Data integrity verified
- [ ] Basic queries work

**Frontend Rollback Success:**
- [ ] Previous version deployed
- [ ] Application loads
- [ ] Login works
- [ ] POS works
- [ ] No console errors

**Full Rollback Success:**
- [ ] Database rolled back
- [ ] Frontend rolled back
- [ ] Data integrity verified
- [ ] Application functional
- [ ] Smoke tests pass

---

## Post-Rollback Actions

### Investigation

**Owner:** Release Manager  
**Duration:** 30 minutes

- [ ] Document rollback reason
- [ ] Investigate root cause
- [ ] Identify fix required
- [ ] Estimate fix time
- [ ] Communicate findings

### Fix Planning

**Owner:** Lead Developer  
**Duration:** 30 minutes

- [ ] Plan fix for issue
- [ ] Estimate fix effort
- [ ] Schedule fix deployment
- [ ] Update deployment plan
- [ ] Communicate timeline

### Re-Deployment

**Owner:** Release Manager  
**Duration:** TBD

- [ ] Fix issue
- [ ] Test fix on staging
- [ ] Update deployment checklist
- [ ] Schedule new deployment
- [ ] Execute deployment

---

## Rollback Risks

### Data Loss Risk

**Risk:** Dropping columns will lose data if new sales were created

**Mitigation:**
- Only rollback if no new transactions occurred
- If new transactions occurred, restore from backup
- Communicate data loss to stakeholders
- Document lost transactions

**Impact:** Low (if rollback triggered immediately)

### Downtime Risk

**Risk:** Application unavailable during rollback

**Mitigation:**
- Schedule rollback during low-traffic period
- Communicate downtime to users
- Minimize rollback duration
- Have rollback procedure documented

**Impact:** Low (rollback takes <15 minutes)

### Partial Rollback Risk

**Risk:** Partial rollback may leave system in inconsistent state

**Mitigation:**
- Test rollback script on staging
- Verify all rollback steps complete
- Run verification queries
- Have full rollback as fallback

**Impact:** Low (rollback script tested)

---

## Rollback Decision Tree

```
DEPLOYMENT FAILURE
│
├─ Migration Error?
│  ├─ Yes → Database Rollback Only
│  └─ No → Continue
│
├─ Frontend Error?
│  ├─ Yes → Frontend Rollback Only
│  └─ No → Continue
│
├─ Data Corruption?
│  ├─ Yes → Full Rollback (Restore from Backup)
│  └─ No → Continue
│
├─ Performance Issue?
│  ├─ Yes → Frontend Rollback Only
│  └─ No → Continue
│
└─ Security Issue?
   └─ Yes → Full Rollback (Restore from Backup)
```

---

## Rollback Contact Information

**Primary Contacts:**
- Database Administrator: [email]
- DevOps Engineer: [email]
- Release Manager: [email]

**Escalation Contacts:**
- CTO: [email]
- CEO: [email]

---

## Rollback Script Location

**File:** `rollback-atomic-checkout.sql`  
**Location:** Project root  
**Last Updated:** July 17, 2026

**Backup Location:**
- Supabase Dashboard > Database > Backups
- Manual backup: [location]

---

## Notes

**Important:**
- Test rollback script on staging before production
- Have rollback script accessible during deployment
- Document every rollback step
- Communicate rollback status continuously
- Be prepared to rollback at any time

**Rollback Timeline:**
1. Decision to rollback: 1 minute
2. Stop traffic: 1 minute
3. Database rollback: 5 minutes
4. Frontend rollback: 3 minutes
5. Verification: 5 minutes
6. Total: 15 minutes

**Critical Path:**
- Stop traffic MUST complete before rollback
- Database rollback MUST complete before frontend rollback
- Verification MUST complete before restoring traffic
