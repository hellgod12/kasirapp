# KasirApp Version 1.0 - Post-Deployment Checklist

**Purpose:** Verify deployment success and system health after go-live  
**Version:** 1.0.0  
**Deployment Date:** TBD  
**Status:** READY

---

## Immediate Verification (T-plus 0 to T-plus 15 minutes)

### 1. Database Migration Verification

**Owner:** Database Administrator  
**Duration:** 5 minutes

- [ ] Verify RPC function exists
- [ ] Verify indexes created
- [ ] Verify columns added
- [ ] Verify permissions granted
- [ ] Verify no migration errors

**Commands:**
```sql
-- Verify RPC function
SELECT * FROM pg_proc WHERE proname = 'process_checkout';

-- Verify indexes
SELECT * FROM pg_indexes WHERE tablename = 'sales' AND indexname LIKE 'idx_sales_%';

-- Verify columns
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_name = 'sales' 
AND column_name IN ('transaction_token', 'customer_id', 'discount_id', 'discount_amount', 'tax_rate', 'tax_amount');

-- Verify permissions
SELECT * FROM pg_proc WHERE proname = 'process_checkout';
```

**Success Criteria:** All migration components verified present

---

### 2. Frontend Deployment Verification

**Owner:** DevOps Engineer  
**Duration:** 3 minutes

- [ ] Verify application loads
- [ ] Verify no console errors
- [ ] Verify API connectivity
- [ ] Verify environment variables loaded
- [ ] Verify PWA service worker registered

**Commands:**
```bash
# Test application
curl https://your-domain.com

# Check console for errors
# Open browser DevTools > Console
```

**Success Criteria:** Application loads without errors

---

### 3. Authentication Verification

**Owner:** QA Engineer  
**Duration:** 5 minutes

- [ ] Login as admin
- [ ] Verify dashboard loads
- [ ] Verify admin permissions
- [ ] Logout
- [ ] Login as cashier
- [ ] Verify POS loads
- [ ] Verify cashier permissions

**Success Criteria:** Both roles can login and access appropriate pages

---

### 4. POS Checkout Verification

**Owner:** QA Engineer  
**Duration:** 10 minutes

- [ ] Navigate to POS
- [ ] Add product to cart
- [ ] Select customer
- [ ] Select discount
- [ ] Select payment method
- [ ] Complete checkout
- [ ] Verify success message
- [ ] Verify receipt generates
- [ ] Verify cart cleared

**Success Criteria:** Checkout completes successfully with all features

---

### 5. Inventory Verification

**Owner:** QA Engineer  
**Duration:** 5 minutes

- [ ] Navigate to inventory
- [ ] Verify stock updated
- [ ] Verify stock movement logged
- [ ] Verify stock accuracy
- [ ] Verify no negative stock

**Commands:**
```sql
-- Verify stock accuracy
SELECT p.id, p.name, p.stock,
  (SELECT COALESCE(SUM(CASE WHEN sm.type = 'in' THEN sm.quantity ELSE -sm.quantity END), 0)
   FROM stock_movements sm 
   WHERE sm.product_id = p.id) as calculated_stock
FROM products p
WHERE p.stock != calculated_stock;
```

**Success Criteria:** Stock updated accurately, no negative stock

---

### 6. Discount Verification

**Owner:** QA Engineer  
**Duration:** 3 minutes

- [ ] Verify discount applied correctly
- [ ] Verify discount amount calculated
- [ ] Verify final amount correct
- [ ] Verify discount logged in sale

**Success Criteria:** Discount applied and calculated correctly

---

### 7. Tax Verification

**Owner:** QA Engineer  
**Duration:** 3 minutes

- [ ] Verify tax calculated
- [ ] Verify tax rate applied
- [ ] Verify tax amount correct
- [ ] Verify tax logged in sale

**Success Criteria:** Tax calculated and applied correctly

---

### 8. Customer Verification

**Owner:** QA Engineer  
**Duration**: 3 minutes

- [ ] Verify customer selected
- [ ] Verify customer logged in sale
- [ ] Verify customer balance updated
- [ ] Verify customer transaction history

**Commands:**
```sql
-- Verify customer balance
SELECT c.id, c.name, c.balance,
  (SELECT COALESCE(SUM(s.total_amount), 0)
   FROM sales s 
   WHERE s.customer_id = c.id) as calculated_balance
FROM customers c
WHERE c.id = 'customer_id';
```

**Success Criteria:** Customer data updated correctly

---

### 9. Supplier Verification

**Owner:** QA Engineer  
**Duration:** 2 minutes

- [ ] Navigate to suppliers
- [ ] Verify supplier list loads
- [ ] Verify supplier details accessible
- [ ] Verify supplier can be created

**Success Criteria:** Supplier functionality works

---

### 10. Reports Verification

**Owner:** QA Engineer  
**Duration:** 5 minutes

- [ ] Navigate to reports
- [ ] Generate sales report
- [ ] Generate profit report
- [ ] Generate inventory report
- [ ] Verify data accuracy
- [ ] Verify PDF export works
- [ ] Verify Excel export works

**Commands:**
```sql
-- Verify profit accuracy
SELECT s.id, s.profit,
  (SELECT COALESCE(SUM((si.price - si.cost) * si.quantity), 0)
   FROM sale_items si 
   WHERE si.sale_id = s.id) as calculated_profit
FROM sales s
WHERE s.profit != calculated_profit;
```

**Success Criteria:** Reports generate with accurate data

---

### 11. Receipt Verification

**Owner:** QA Engineer  
**Duration:** 2 minutes

- [ ] Generate receipt after checkout
- [ ] Verify receipt contains all data
- [ ] Verify receipt PDF downloads
- [ ] Verify receipt formatting correct

**Success Criteria:** Receipt generates and downloads correctly

---

### 12. Backup Verification

**Owner:** Database Administrator  
**Duration:** 2 minutes

- [ ] Verify backup still enabled
- [ ] Verify backup schedule
- [ ] Verify backup retention
- [ ] Test backup restore (optional)

**Success Criteria:** Backup system functional

---

## Extended Monitoring (T-plus 15 to T-plus 60 minutes)

### 13. Log Monitoring

**Owner:** DevOps Engineer  
**Duration:** 30 minutes

- [ ] Monitor Supabase logs for errors
- [ ] Monitor Vercel logs for errors
- [ ] Monitor RPC execution time
- [ ] Monitor transaction success rate
- [ ] Monitor error rates

**Commands:**
```sql
-- Check for RPC errors
SELECT * FROM logs WHERE error = true ORDER BY created_at DESC LIMIT 10;

-- Check transaction success rate
SELECT 
  COUNT(*) FILTER (WHERE success = true) * 100.0 / COUNT(*) as success_rate
FROM sales
WHERE created_at >= NOW() - INTERVAL '1 hour';
```

**Success Criteria:** No critical errors, success rate >99%

---

### 14. Performance Monitoring

**Owner:** DevOps Engineer  
**Duration:** 30 minutes

- [ ] Monitor dashboard load time
- [ ] Monitor POS load time
- [ ] Monitor checkout time
- [ ] Monitor database query time
- [ ] Monitor API response time

**Success Criteria:** All performance metrics within targets

---

### 15. Transaction Monitoring

**Owner:** QA Engineer  
**Duration:** 30 minutes

- [ ] Monitor first 10 transactions
- [ ] Verify all transactions successful
- [ ] Verify no duplicate transactions
- [ ] Verify no negative stock
- [ ] Verify stock accuracy
- [ ] Verify profit accuracy

**Commands:**
```sql
-- Check for duplicate transactions
SELECT transaction_token, COUNT(*) 
FROM sales 
WHERE transaction_token IS NOT NULL
GROUP BY transaction_token 
HAVING COUNT(*) > 1;

-- Check for negative stock
SELECT * FROM products WHERE stock < 0;
```

**Success Criteria:** All transactions successful, no data issues

---

## Data Validation (T-plus 60 to T-plus 90 minutes)

### 16. Stock Accuracy Validation

**Owner:** Database Administrator  
**Duration:** 10 minutes

- [ ] Run stock accuracy query
- [ ] Verify no discrepancies
- [ ] Investigate any discrepancies
- [ ] Document results

**Commands:**
```sql
-- Comprehensive stock accuracy check
SELECT p.id, p.name, p.stock,
  (SELECT COALESCE(SUM(CASE WHEN sm.type = 'in' THEN sm.quantity ELSE -sm.quantity END), 0)
   FROM stock_movements sm 
   WHERE sm.product_id = p.id) as calculated_stock,
  p.stock - (SELECT COALESCE(SUM(CASE WHEN sm.type = 'in' THEN sm.quantity ELSE -sm.quantity END), 0)
   FROM stock_movements sm 
   WHERE sm.product_id = p.id) as difference
FROM products p
WHERE p.stock != (SELECT COALESCE(SUM(CASE WHEN sm.type = 'in' THEN sm.quantity ELSE -sm.quantity END), 0)
   FROM stock_movements sm 
   WHERE sm.product_id = p.id);
```

**Success Criteria:** No stock discrepancies

---

### 17. Profit Accuracy Validation

**Owner:** Database Administrator  
**Duration:** 10 minutes

- [ ] Run profit accuracy query
- [ ] Verify no discrepancies
- [ ] Investigate any discrepancies
- [ ] Document results

**Commands:**
```sql
-- Comprehensive profit accuracy check
SELECT s.id, s.total_amount, s.profit,
  (SELECT COALESCE(SUM((si.price - si.cost) * si.quantity), 0)
   FROM sale_items si 
   WHERE si.sale_id = s.id) as calculated_profit,
  s.profit - (SELECT COALESCE(SUM((si.price - si.cost) * si.quantity), 0)
   FROM sale_items si 
   WHERE si.sale_id = s.id) as difference
FROM sales s
WHERE s.profit != (SELECT COALESCE(SUM((si.price - si.cost) * si.quantity), 0)
   FROM sale_items si 
   WHERE si.sale_id = s.id);
```

**Success Criteria:** No profit discrepancies

---

### 18. Customer Balance Validation

**Owner:** Database Administrator  
**Duration:** 5 minutes

- [ ] Run customer balance query
- [ ] Verify no discrepancies
- [ ] Investigate any discrepancies
- [ ] Document results

**Commands:**
```sql
-- Customer balance accuracy check
SELECT c.id, c.name, c.balance,
  (SELECT COALESCE(SUM(s.total_amount), 0)
   FROM sales s 
   WHERE s.customer_id = c.id) as calculated_balance,
  c.balance - (SELECT COALESCE(SUM(s.total_amount), 0)
   FROM sales s 
   WHERE s.customer_id = c.id) as difference
FROM customers c
WHERE c.balance != (SELECT COALESCE(SUM(s.total_amount), 0)
   FROM sales s 
   WHERE s.customer_id = c.id);
```

**Success Criteria:** No customer balance discrepancies

---

### 19. Transaction Completeness Validation

**Owner:** Database Administrator  
**Duration:** 5 minutes

- [ ] Verify all sales have sale items
- [ ] Verify all sales have stock movements
- [ ] Verify no orphaned records
- [ ] Document results

**Commands:**
```sql
-- Check for sales without items
SELECT s.id, s.created_at
FROM sales s
WHERE NOT EXISTS (
  SELECT 1 FROM sale_items si WHERE si.sale_id = s.id
);

-- Check for sales without stock movements
SELECT s.id, s.created_at
FROM sales s
WHERE NOT EXISTS (
  SELECT 1 FROM stock_movements sm WHERE sm.reference_id = s.id::TEXT
);
```

**Success Criteria:** No orphaned records

---

## User Acceptance Testing (T-plus 90 to T-plus 120 minutes)

### 20. Admin Workflow Testing

**Owner:** QA Engineer  
**Duration:** 15 minutes

- [ ] Create product
- [ ] Edit product
- [ ] Delete product
- [ ] Create customer
- [ ] Create discount
- [ ] Generate report
- [ ] Verify all operations successful

**Success Criteria:** All admin workflows work

---

### 21. Cashier Workflow Testing

**Owner:** QA Engineer  
**Duration:** 15 minutes

- [ ] Login as cashier
- [ ] Add products to cart
- [ ] Apply discount
- [ ] Select customer
- [ ] Complete checkout
- [ ] Generate receipt
- [ ] Verify all operations successful

**Success Criteria:** All cashier workflows work

---

## Final Verification (T-plus 120 to T-plus 150 minutes)

### 22. System Health Check

**Owner:** DevOps Engineer  
**Duration:** 10 minutes

- [ ] Check database size
- [ ] Check connection pool
- [ ] Check storage usage
- [ ] Check API rate limits
- [ ] Document system health

**Commands:**
```sql
-- Check database size
SELECT pg_size_pretty(pg_database_size('postgres'));

-- Check connection count
SELECT count(*) FROM pg_stat_activity;
```

**Success Criteria:** System healthy, no resource issues

---

### 23. Security Verification

**Owner:** DevOps Engineer  
**Duration:** 5 minutes

- [ ] Verify RLS policies active
- [ ] Verify no unauthorized access
- [ ] Verify environment variables secure
- [ ] Verify no exposed secrets
- [ ] Document security status

**Success Criteria:** Security intact, no vulnerabilities

---

### 24. Documentation Update

**Owner:** Release Manager  
**Duration:** 5 minutes

- [ ] Document deployment results
- [ ] Update deployment log
- [ ] Document any issues
- [ ] Document resolutions
- [ ] Archive deployment artifacts

**Success Criteria:** Documentation complete

---

### 25. Stakeholder Notification

**Owner:** Release Manager  
**Duration:** 5 minutes

- [ ] Notify stakeholders of success
- [ ] Provide deployment summary
- [ ] Document known limitations
- [ ] Provide support contact
- [ ] Schedule follow-up

**Success Criteria:** Stakeholders notified

---

## Rollback Triggers

**Immediate Rollback (During Verification):**
- Transaction failure rate >5%
- Data corruption detected
- Critical performance degradation
- Security vulnerability discovered
- Financial loss detected

**Rollback Procedure:** See ROLLBACK_PLAN.md

---

## Success Criteria Summary

### Critical Success Criteria (Must Pass)

- [ ] Migration completes without errors
- [ ] Frontend deploys successfully
- [ ] Authentication works for both roles
- [ ] POS checkout works
- [ ] Stock updates accurately
- [ ] No negative stock
- [ ] No duplicate transactions
- [ ] Transaction success rate >99%
- [ ] No data corruption
- [ ] No critical errors in logs

### Important Success Criteria (Should Pass)

- [ ] Discount applies correctly
- [ ] Tax calculates correctly
- [ ] Customer data updates correctly
- [ ] Reports generate accurately
- [ ] Receipt generates correctly
- [ ] Performance within targets
- [ ] Security intact

### Nice-to-Have Success Criteria (Can Fail)

- [ ] All admin workflows tested
- [ ] All cashier workflows tested
- [ ] System health optimal
- [ ] Documentation complete

---

## Contact Information

**Verification Team:**
- Database Administrator: [email]
- DevOps Engineer: [email]
- QA Engineer: [email]
- Release Manager: [email]

**Escalation:**
- CTO: [email]
- CEO: [email]

---

## Verification Timeline

| Phase | Start | End | Duration | Owner |
|-------|-------|-----|----------|-------|
| Immediate Verification | T+0 | T+15 | 15 min | Team |
| Extended Monitoring | T+15 | T+60 | 45 min | DevOps |
| Data Validation | T+60 | T+90 | 30 min | DBA |
| User Acceptance Testing | T+90 | T+120 | 30 min | QA |
| Final Verification | T+120 | T+150 | 30 min | Team |
| **TOTAL** | **T+0** | **T+150** | **150 min** | **Team** |

---

## Notes

**Important:**
- Do not skip any verification steps
- Document all results
- Investigate any discrepancies
- Be prepared to rollback if issues found
- Communicate issues immediately

**Critical Path:**
- Migration verification MUST pass before proceeding
- Frontend verification MUST pass before proceeding
- Transaction monitoring MUST show success rate >99%
- Data validation MUST show no discrepancies

**Rollback Decision:**
If any critical success criteria fails, initiate rollback immediately per ROLLBACK_PLAN.md.
