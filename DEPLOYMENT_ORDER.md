# KasirApp Version 1.0 - Deployment Order

**Purpose:** Exact step-by-step deployment sequence  
**Version:** 1.0.0  
**Deployment Date:** TBD  
**Status:** READY TO EXECUTE

---

## Pre-Deployment Phase (T-minus 1 Hour)

### 1. Team Coordination (T-minus 60 minutes)

**Owner:** Release Manager  
**Duration:** 10 minutes

- [ ] Notify all stakeholders of deployment window
- [ ] Confirm team availability
- [ ] Confirm rollback plan is ready
- [ ] Confirm monitoring tools are active
- [ ] Set up communication channel (Slack/Discord)

**Success Criteria:** All team members confirmed available

---

### 2. Pre-Deployment Verification (T-minus 50 minutes)

**Owner:** Database Administrator  
**Duration:** 10 minutes

- [ ] Verify database backup is recent (<24 hours)
- [ ] Verify backup can be restored (test on staging)
- [ ] Check current database size
- [ ] Verify sufficient database capacity
- [ ] Document current database state

**Commands:**
```sql
-- Check database size
SELECT pg_size_pretty(pg_database_size('postgres'));

-- Check table sizes
SELECT 
  schemaname,
  tablename,
  pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) AS size
FROM pg_tables
WHERE schemaname = 'public'
ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC;
```

**Success Criteria:** Database backup verified, sufficient capacity confirmed

---

### 3. Environment Variables Verification (T-minus 40 minutes)

**Owner:** DevOps Engineer  
**Duration:** 10 minutes

- [ ] Verify `NEXT_PUBLIC_SUPABASE_URL` in Vercel
- [ ] Verify `NEXT_PUBLIC_SUPABASE_ANON_KEY` in Vercel
- [ ] Verify variables match production Supabase project
- [ ] Document environment variable values

**Commands:**
```bash
# Verify environment variables in Vercel CLI
vercel env ls
vercel env pull .env.production
```

**Success Criteria:** All environment variables set correctly

---

### 4. Rollback Script Preparation (T-minus 30 minutes)

**Owner:** Database Administrator  
**Duration:** 10 minutes

- [ ] Create rollback script (see ROLLBACK_PLAN.md)
- [ ] Test rollback script on staging
- [ ] Document rollback script location
- [ ] Ensure rollback script is accessible

**Success Criteria:** Rollback script tested and ready

---

### 5. Code Freeze (T-minus 20 minutes)

**Owner:** Release Manager  
**Duration:** 5 minutes

- [ ] Announce code freeze to team
- [ ] Lock main branch
- [ ] Stop all merges
- [ ] Confirm no pending PRs

**Success Criteria:** Code freeze enforced

---

### 6. Final Smoke Test on Staging (T-minus 15 minutes)

**Owner:** QA Engineer  
**Duration:** 15 minutes

- [ ] Login to staging
- [ ] Test POS checkout
- [ ] Verify RPC function works
- [ ] Verify customer selection
- [ ] Verify discount selection
- [ ] Verify reports generate

**Success Criteria:** All smoke tests pass on staging

---

## Deployment Phase (T-minus 0 to T-plus 30 minutes)

### 7. Database Backup (T-minus 5 minutes)

**Owner:** Database Administrator  
**Duration:** 5 minutes

- [ ] Create manual database backup
- [ ] Document backup timestamp
- [ ] Verify backup completed successfully

**Commands:**
```sql
-- Manual backup via Supabase Dashboard
-- Or use pg_dump if available
```

**Success Criteria:** Backup completed and documented

---

### 8. Export Current Schema (T-minus 0 minutes)

**Owner:** Database Administrator  
**Duration:** 2 minutes

- [ ] Export current database schema
- [ ] Save schema to file
- [ ] Document schema location

**Commands:**
```sql
-- Export schema via Supabase Dashboard
-- Or use pg_dump --schema-only
```

**Success Criteria:** Schema exported and documented

---

### 9. Run Database Migration (T-plus 2 minutes)

**Owner:** Database Administrator  
**Duration:** 5 minutes

- [ ] Open Supabase SQL Editor
- [ ] Load `atomic-checkout-migration.sql`
- [ ] Execute migration
- [ ] Verify no errors
- [ ] Document migration completion

**Commands:**
```sql
-- Execute atomic-checkout-migration.sql in Supabase SQL Editor
```

**Success Criteria:** Migration completes without errors

---

### 10. Verify Migration (T-plus 7 minutes)

**Owner:** Database Administrator  
**Duration:** 5 minutes

- [ ] Verify RPC function exists
- [ ] Verify indexes created
- [ ] Verify columns added
- [ ] Verify permissions granted
- [ ] Test RPC function with sample data

**Commands:**
```sql
-- Verify RPC function
SELECT * FROM pg_proc WHERE proname = 'process_checkout';

-- Verify indexes
SELECT * FROM pg_indexes WHERE tablename = 'sales';

-- Verify columns
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_name = 'sales';

-- Test RPC function
SELECT process_checkout(
  '[{"product_id": "test-id", "quantity": 1, "price": 10000, "cost": 5000}]'::jsonb,
  'cash',
  'test-user-id',
  'test-token-123'
);
```

**Success Criteria:** All migration components verified

---

### 11. Deploy Frontend to Production (T-plus 12 minutes)

**Owner:** DevOps Engineer  
**Duration:** 10 minutes

- [ ] Build production bundle
- [ ] Deploy to Vercel
- [ ] Verify deployment successful
- [ ] Clear Vercel cache
- [ ] Document deployment URL

**Commands:**
```bash
# Build production bundle
npm run build

# Deploy to Vercel
vercel --prod

# Or use git push to trigger deployment
git push origin main
```

**Success Criteria:** Frontend deployed successfully

---

### 12. Verify Environment Variables (T-plus 22 minutes)

**Owner:** DevOps Engineer  
**Duration:** 3 minutes

- [ ] Verify environment variables in production
- [ ] Test application loads
- [ ] Verify no console errors
- [ ] Verify API connectivity

**Commands:**
```bash
# Test application
curl https://your-domain.com
```

**Success Criteria:** Application loads without errors

---

### 13. Smoke Tests - Critical Workflows (T-plus 25 minutes)

**Owner:** QA Engineer  
**Duration:** 10 minutes

**Login Test:**
- [ ] Navigate to login page
- [ ] Login as admin
- [ ] Verify dashboard loads
- [ ] Logout
- [ ] Login as cashier
- [ ] Verify POS loads

**POS Checkout Test:**
- [ ] Add product to cart
- [ ] Select customer
- [ ] Select discount
- [ ] Select payment method
- [ ] Complete checkout
- [ ] Verify success message
- [ ] Verify receipt generates

**Inventory Test:**
- [ ] Navigate to inventory
- [ ] Verify stock updated
- [ ] Verify stock movement logged

**Reports Test:**
- [ ] Navigate to reports
- [ ] Generate sales report
- [ ] Verify data accuracy

**Success Criteria:** All smoke tests pass

---

### 14. Monitor Logs (T-plus 35 minutes)

**Owner:** DevOps Engineer  
**Duration:** 5 minutes

- [ ] Check Supabase logs for errors
- [ ] Check Vercel logs for errors
- [ ] Monitor RPC execution time
- [ ] Monitor transaction success rate
- [ ] Document any issues

**Commands:**
```sql
-- Check for RPC errors
SELECT * FROM logs WHERE error = true ORDER BY created_at DESC LIMIT 10;
```

**Success Criteria:** No critical errors in logs

---

### 15. Verify Reports and Stock (T-plus 40 minutes)

**Owner:** QA Engineer  
**Duration:** 5 minutes

- [ ] Verify stock accuracy
- [ ] Verify profit accuracy
- [ ] Verify sales totals
- [ ] Verify customer balances
- [ ] Verify discount usage

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
```

**Success Criteria:** All data verified accurate

---

### 16. Declare Deployment Complete (T-plus 45 minutes)

**Owner:** Release Manager  
**Duration:** 2 minutes

- [ ] Confirm all steps completed
- [ ] Confirm all tests passed
- [ ] Confirm no critical errors
- [ ] Notify stakeholders of success
- [ ] Document deployment completion

**Success Criteria:** Deployment declared complete

---

## Post-Deployment Phase (T-plus 45 to T-plus 90 minutes)

### 17. Extended Monitoring (T-plus 45 to T-plus 90 minutes)

**Owner:** DevOps Engineer  
**Duration:** 45 minutes

- [ ] Monitor error logs continuously
- [ ] Monitor performance metrics
- [ ] Monitor transaction success rate
- [ ] Monitor RPC execution time
- [ ] Document any issues

**Success Criteria:** No critical issues for 45 minutes

---

### 18. User Communication (T-plus 50 minutes)

**Owner:** Release Manager  
**Duration:** 5 minutes

- [ ] Notify users of deployment
- [ ] Provide deployment summary
- [ ] Document known limitations
- [ ] Provide support contact

**Success Criteria:** Users notified

---

### 19. Post-Deployment Verification (T-plus 60 minutes)

**Owner:** QA Engineer  
**Duration:** 10 minutes

- [ ] Verify first 10 transactions successful
- [ ] Verify stock accuracy after transactions
- [ ] Verify profit accuracy after transactions
- [ ] Verify no duplicate transactions
- [ ] Verify no negative stock

**Success Criteria:** All verifications pass

---

### 20. Deployment Sign-Off (T-plus 90 minutes)

**Owner:** Release Manager  
**Duration:** 5 minutes

- [ ] Complete deployment checklist
- [ ] Obtain team sign-offs
- [ ] Document deployment results
- [ ] Archive deployment artifacts
- [ ] Close deployment window

**Success Criteria:** Deployment signed off

---

## Rollback Triggers

**Immediate Rollback (Stop Deployment):**
- Migration fails with error
- Database backup fails
- Frontend deployment fails
- Critical error in smoke tests

**Post-Deployment Rollback (Within 1 Hour):**
- Transaction failure rate >5%
- Data corruption detected
- Critical performance degradation
- Security vulnerability discovered

**Rollback Procedure:** See ROLLBACK_PLAN.md

---

## Contact Information

**Deployment Team:**
- Release Manager: [email]
- Database Administrator: [email]
- DevOps Engineer: [email]
- QA Engineer: [email]

**Escalation:**
- CTO: [email]
- CEO: [email]

---

## Deployment Timeline Summary

| Phase | Start | End | Duration | Owner |
|-------|-------|-----|----------|-------|
| Pre-Deployment | T-60 | T-0 | 60 min | Release Manager |
| Database Backup | T-5 | T-0 | 5 min | DBA |
| Migration | T+0 | T+7 | 7 min | DBA |
| Frontend Deploy | T+7 | T+22 | 15 min | DevOps |
| Smoke Tests | T+22 | T+35 | 13 min | QA |
| Verification | T+35 | T+45 | 10 min | QA |
| Monitoring | T+45 | T+90 | 45 min | DevOps |
| Sign-Off | T+90 | T+95 | 5 min | Release Manager |
| **TOTAL** | **T-60** | **T+95** | **155 min** | **Team** |

---

## Success Criteria

**Deployment Success:**
- [ ] All pre-deployment checks pass
- [ ] Migration completes without errors
- [ ] Frontend deploys successfully
- [ ] All smoke tests pass
- [ ] No critical errors in logs
- [ ] Data accuracy verified
- [ ] No rollback triggered

**Rollback Success:**
- [ ] Rollback script executes without errors
- [ ] Database restored to previous state
- [ ] Frontend reverted to previous version
- [ ] Data accuracy verified
- [ ] Application functional

---

## Notes

**Important:**
- Do not skip any steps
- Do not proceed if a step fails
- Document every step
- Communicate issues immediately
- Be prepared to rollback at any time

**Migration Order:**
This deployment assumes all previous migrations have been run. If not, run migrations in this order:
1. supabase-schema.sql
2. supabase-auth-migration.sql
3. supabase-rls-policies.sql
4. customers-migration.sql
5. discounts-migration.sql
6. tax-migration.sql
7. store-profile-migration.sql
8. barcode-migration.sql
9. hpp-migration.sql
10. expenses-migration.sql
11. transaction-logs-migration.sql
12. atomic-checkout-migration.sql (THIS DEPLOYMENT)

**Critical Path:**
- Database backup MUST complete before migration
- Migration MUST complete before frontend deployment
- Smoke tests MUST pass before declaring success
- Monitoring MUST continue for 45 minutes after deployment
