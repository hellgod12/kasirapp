# KasirApp Version 1.0 - Support Runbook

**Purpose:** Guide support team in troubleshooting common issues  
**Version:** 1.0  
**Last Updated:** July 16, 2026

---

## Quick Reference

### Emergency Contacts
- **Release Manager:** [email]
- **Lead Developer:** [email]
- **Database Administrator:** [email]
- **Support Lead:** [email]

### Critical Systems
- **Database:** Supabase PostgreSQL
- **Frontend:** Next.js 14 (Vercel/Netlify)
- **Authentication:** Supabase Auth
- **Monitoring:** Supabase Dashboard

### Key Resources
- **Supabase Dashboard:** [URL]
- **Application URL:** [URL]
- **Admin Panel:** [URL]
- **Documentation:** [URL]

---

## Common Issues & Solutions

### Authentication Issues

#### User Cannot Login

**Symptoms:**
- Login fails with error message
- User sees "Invalid login credentials"
- Redirect loop on login page

**Troubleshooting Steps:**
1. Verify user exists in Supabase Auth
   - Go to Supabase Dashboard > Authentication > Users
   - Search for user email
   - Check if user is confirmed

2. Verify user profile exists in database
   ```sql
   SELECT * FROM profiles WHERE email = 'user@email.com';
   ```

3. Check if user role is correct
   ```sql
   SELECT id, email, role FROM profiles WHERE email = 'user@email.com';
   ```

4. Verify environment variables
   - Check `NEXT_PUBLIC_SUPABASE_URL`
   - Check `NEXT_PUBLIC_SUPABASE_ANON_KEY`

**Solutions:**
- If user not confirmed: Resend confirmation email
- If profile missing: Create profile in database
- If role incorrect: Update role in profiles table
- If env vars wrong: Update environment variables

---

#### Session Expiring Too Quickly

**Symptoms:**
- User logged out frequently
- Session expires after few minutes

**Troubleshooting Steps:**
1. Check Supabase Auth session settings
   - Go to Supabase Dashboard > Authentication > URL Configuration
   - Check session timeout setting

2. Check browser console for errors
   - Open browser DevTools
   - Check Console tab for auth errors

**Solutions:**
- Adjust session timeout in Supabase settings
- Clear browser cookies and cache
- Check for network issues

---

### POS Issues

#### Checkout Fails

**Symptoms:**
- Checkout button shows error
- Transaction not completed
- Stock not deducted

**Troubleshooting Steps:**
1. Check browser console for error message
2. Verify cart has items
3. Verify payment method selected
4. Check if RPC function exists
   ```sql
   SELECT * FROM pg_proc WHERE proname = 'process_checkout';
   ```

5. Check Supabase logs for RPC errors
   - Go to Supabase Dashboard > Logs
   - Filter by RPC errors

**Common Errors:**
- "Insufficient stock" - Product has insufficient stock
- "Duplicate transaction" - Transaction already processed
- "Discount has expired" - Selected discount is no longer valid
- "Customer not found" - Selected customer does not exist

**Solutions:**
- For insufficient stock: Add stock or remove item from cart
- For duplicate transaction: Refresh page and try again
- For expired discount: Select different discount or none
- For customer not found: Select different customer or none

---

#### Product Not Found in Search

**Symptoms:**
- Product exists but not showing in search
- Search returns no results

**Troubleshooting Steps:**
1. Check if product is active
   ```sql
   SELECT * FROM products WHERE name LIKE '%search_term%' AND is_active = true;
   ```

2. Check if product category is correct
3. Verify search term spelling
4. Check if product has stock

**Solutions:**
- If product inactive: Activate product in inventory
- If category wrong: Update product category
- If no stock: Add stock to product

---

#### Barcode Scanner Not Working

**Symptoms:**
- Barcode scanner doesn't add product
- No response when scanning

**Troubleshooting Steps:**
1. Check if barcode field has focus
2. Verify barcode is in database
   ```sql
   SELECT * FROM products WHERE barcode = '123456789';
   ```

3. Check if product is active
4. Test with different barcode scanner

**Solutions:**
- Ensure barcode field is clicked/focused
- Add barcode to product if missing
- Activate product if inactive
- Try different barcode scanner or keyboard input

---

### Inventory Issues

#### Stock Not Updating

**Symptoms:**
- Stock not deducted after sale
- Stock not added after stock-in
- Stock shows incorrect value

**Troubleshooting Steps:**
1. Check stock movements table
   ```sql
   SELECT * FROM stock_movements WHERE product_id = 'product_id' ORDER BY created_at DESC LIMIT 10;
   ```

2. Check if RPC function is being used
   - Recent sales should use `process_checkout`
   - Old sales used manual updates

3. Verify stock calculation
   ```sql
   SELECT p.id, p.name, p.stock,
     (SELECT COALESCE(SUM(CASE WHEN sm.type = 'in' THEN sm.quantity ELSE -sm.quantity END), 0)
      FROM stock_movements sm 
      WHERE sm.product_id = p.id) as calculated_stock
   FROM products p
   WHERE p.id = 'product_id';
   ```

**Solutions:**
- If stock mismatched: Manually correct stock
- If RPC not used: Ensure latest code is deployed
- If calculation wrong: Investigate stock movements

---

#### Negative Stock Detected

**Symptoms:**
- Product stock shows negative value
- Alert triggered in monitoring

**Troubleshooting Steps:**
1. Identify product with negative stock
   ```sql
   SELECT * FROM products WHERE stock < 0;
   ```

2. Check recent stock movements
   ```sql
   SELECT * FROM stock_movements WHERE product_id = 'product_id' ORDER BY created_at DESC LIMIT 20;
   ```

3. Check for concurrent sales
   - Look for duplicate transaction tokens
   - Check for race conditions

**Solutions:**
- Immediate: Set stock to 0 or correct value
- Investigation: Review transaction logs
- Prevention: Ensure RPC function is used

---

### Reports Issues

#### Report Not Generating

**Symptoms:**
- Report page shows error
- Report generation fails
- No data in report

**Troubleshooting Steps:**
1. Check browser console for errors
2. Verify date range is valid
3. Check if data exists for date range
   ```sql
   SELECT COUNT(*) FROM sales WHERE created_at >= 'start_date' AND created_at <= 'end_date';
   ```

4. Check Supabase logs for query errors

**Solutions:**
- Select valid date range
- Ensure data exists for period
- Check for database connection issues

---

#### Report Numbers Don't Match

**Symptoms:**
- Report totals don't match manual calculation
- Profit calculation seems wrong
- Sales totals inconsistent

**Troubleshooting Steps:**
1. Verify sales data
   ```sql
   SELECT SUM(total_amount) FROM sales WHERE created_at >= 'start_date' AND created_at <= 'end_date';
   ```

2. Verify profit calculation
   ```sql
   SELECT SUM(profit) FROM sales WHERE created_at >= 'start_date' AND created_at <= 'end_date';
   ```

3. Check sale items for accuracy
   ```sql
   SELECT * FROM sale_items WHERE sale_id IN (
     SELECT id FROM sales WHERE created_at >= 'start_date' AND created_at <= 'end_date'
   );
   ```

**Solutions:**
- Verify HPP values are correct
- Check for voided transactions
- Ensure discounts and taxes are included correctly

---

### Database Issues

#### Database Connection Failed

**Symptoms:**
- Application shows connection error
- Cannot login
- Data not loading

**Troubleshooting Steps:**
1. Check Supabase status page
2. Verify environment variables
3. Check Supabase dashboard for outages
4. Test database connection
   ```sql
   SELECT 1;
   ```

**Solutions:**
- Wait for Supabase to resolve outage
- Update environment variables if changed
- Restart application

---

#### Query Too Slow

**Symptoms:**
- Page loads slowly
- Reports take long to generate
- Timeout errors

**Troubleshooting Steps:**
1. Check Supabase query performance
   - Go to Supabase Dashboard > Database > Query Performance
2. Identify slow queries
3. Check if indexes exist
   ```sql
   SELECT * FROM pg_indexes WHERE tablename = 'table_name';
   ```

**Solutions:**
- Add missing indexes
- Optimize queries
- Increase database resources if needed

---

### Payment Issues

#### Payment Method Not Available

**Symptoms:**
- Payment method not showing in dropdown
- Cannot select payment method

**Troubleshooting Steps:**
1. Check payment methods table
   ```sql
   SELECT * FROM payment_methods WHERE is_active = true;
   ```

2. Verify payment method is active
3. Check if payment method exists

**Solutions:**
- Activate payment method in settings
- Add payment method if missing
- Refresh page

---

#### Discount Not Applying

**Symptoms:**
- Discount selected but not applied
- Total amount doesn't change
- Error message about discount

**Troubleshooting Steps:**
1. Check if discount is active
   ```sql
   SELECT * FROM discounts WHERE id = 'discount_id' AND is_active = true;
   ```

2. Check discount validity period
   ```sql
   SELECT * FROM discounts WHERE id = 'discount_id' AND valid_from <= NOW() AND (valid_until IS NULL OR valid_until >= NOW());
   ```

3. Check minimum purchase requirement
   ```sql
   SELECT * FROM discounts WHERE id = 'discount_id' AND min_purchase <= cart_total;
   ```

**Solutions:**
- Activate discount if inactive
- Select different discount if expired
- Add more items to meet minimum purchase
- Remove discount if not applicable

---

### Customer Issues

#### Customer Not Found

**Symptoms:**
- Customer not showing in dropdown
- Cannot select customer
- Error message about customer

**Troubleshooting Steps:**
1. Check if customer exists
   ```sql
   SELECT * FROM customers WHERE id = 'customer_id';
   ```

2. Check if customer is active
   ```sql
   SELECT * FROM customers WHERE id = 'customer_id' AND is_active = true;
   ```

**Solutions:**
- Activate customer if inactive
- Create customer if missing
- Select different customer

---

#### Customer Balance Incorrect

**Symptoms:**
- Customer balance doesn't match transactions
- Balance shows negative when shouldn't
- Balance not updating

**Troubleshooting Steps:**
1. Calculate expected balance
   ```sql
   SELECT c.name, c.balance,
     (SELECT COALESCE(SUM(s.total_amount), 0)
      FROM sales s 
      WHERE s.customer_id = c.id) as calculated_balance
   FROM customers c
   WHERE c.id = 'customer_id';
   ```

2. Check customer transactions
   ```sql
   SELECT * FROM sales WHERE customer_id = 'customer_id' ORDER BY created_at DESC;
   ```

**Solutions:**
- Manually correct balance if needed
- Investigate missing transactions
- Verify transaction logging

---

## Data Recovery Procedures

### Restore from Backup

**When to Use:**
- Data corruption detected
- Accidental data deletion
- Critical database error

**Procedure:**
1. Identify backup to restore
   - Go to Supabase Dashboard > Database > Backups
   - Select appropriate backup point

2. Stop application
   - Put maintenance page up
   - Stop accepting new transactions

3. Restore backup
   - Click restore in Supabase Dashboard
   - Wait for restore to complete

4. Verify data
   - Run verification queries
   - Check critical data points

5. Resume application
   - Remove maintenance page
   - Monitor for issues

**Important:**
- Document the restore process
- Investigate root cause
- Implement prevention measures

---

### Manual Stock Correction

**When to Use:**
- Stock shows incorrect value
- Stock calculation error
- Negative stock detected

**Procedure:**
1. Identify correct stock value
   ```sql
   SELECT p.id, p.name, p.stock,
     (SELECT COALESCE(SUM(CASE WHEN sm.type = 'in' THEN sm.quantity ELSE -sm.quantity END), 0)
      FROM stock_movements sm 
      WHERE sm.product_id = p.id) as calculated_stock
   FROM products p
   WHERE p.id = 'product_id';
   ```

2. Update stock to correct value
   ```sql
   UPDATE products SET stock = correct_value WHERE id = 'product_id';
   ```

3. Create stock movement for correction
   ```sql
   INSERT INTO stock_movements (product_id, type, quantity, notes, created_by)
   VALUES ('product_id', 'adjustment', difference, 'Manual correction', 'user_id');
   ```

4. Verify correction
   ```sql
   SELECT * FROM products WHERE id = 'product_id';
   ```

**Important:**
- Document reason for correction
- Get approval before correction
- Monitor for recurrence

---

### Transaction Recovery

**When to Use:**
- Transaction failed but payment received
- Transaction incomplete
- Stock deducted but sale not created

**Procedure:**
1. Identify failed transaction
   - Check transaction logs
   - Check stock movements
   - Check payment records

2. Verify payment received
   - Confirm with customer
   - Check payment method records

3. Manually create transaction
   ```sql
   INSERT INTO sales (total_amount, total_cost, profit, payment_method, customer_id, discount_id, discount_amount, tax_rate, tax_amount, transaction_token, created_by)
   VALUES (total_amount, total_cost, profit, payment_method, customer_id, discount_id, discount_amount, tax_rate, tax_amount, transaction_token, user_id);
   ```

4. Create sale items
   ```sql
   INSERT INTO sale_items (sale_id, product_id, quantity, price, cost, subtotal)
   VALUES (sale_id, product_id, quantity, price, cost, subtotal);
   ```

5. Verify transaction
   ```sql
   SELECT * FROM sales WHERE id = 'sale_id';
   ```

**Important:**
- Document recovery process
- Investigate root cause
- Implement prevention measures

---

## Performance Issues

### Slow Page Load

**Symptoms:**
- Page takes >2 seconds to load
- Loading spinner shows for long time
- User reports slowness

**Troubleshooting Steps:**
1. Check network connection
2. Check browser console for errors
3. Check Supabase query performance
4. Check application bundle size

**Solutions:**
- Optimize images
- Implement lazy loading
- Add caching
- Optimize database queries

---

### High Memory Usage

**Symptoms:**
- Application becomes slow over time
- Browser crashes
- Memory warnings

**Troubleshooting Steps:**
1. Check browser memory usage
2. Check for memory leaks
3. Check for large data sets
4. Check for infinite loops

**Solutions:**
- Implement pagination
- Clear unused data
- Fix memory leaks
- Optimize data fetching

---

## Security Issues

### Unauthorized Access

**Symptoms:**
- User accessing pages they shouldn't
- Data visible to wrong users
- Role not enforced

**Troubleshooting Steps:**
1. Verify user role
   ```sql
   SELECT * FROM profiles WHERE id = 'user_id';
   ```

2. Check RLS policies
   ```sql
   SELECT * FROM pg_policies WHERE tablename = 'table_name';
   ```

3. Verify ProtectedRoute component

**Solutions:**
- Update user role if incorrect
- Fix RLS policies if broken
- Update ProtectedRoute if needed

---

### Data Leak

**Symptoms:**
- User sees data they shouldn't
- Cross-user data access
- Sensitive data exposed

**Troubleshooting Steps:**
1. Identify leaked data
2. Identify affected users
3. Check RLS policies
4. Check query filters

**Solutions:**
- Fix RLS policies immediately
- Audit all data access
- Notify affected users
- Implement additional safeguards

---

## Escalation Procedures

### When to Escalate

**Escalate to Lead Developer:**
- Cannot resolve issue within 30 minutes
- Issue affects multiple users
- Issue involves data corruption
- Issue involves security

**Escalate to Release Manager:**
- Issue affects all users
- System down
- Data loss
- Security breach

**Escalate to CTO:**
- Critical system failure
- Major data loss
- Security incident
- Financial loss

### Escalation Process

1. **Document Issue**
   - Create support ticket
   - Document symptoms
   - Document troubleshooting steps
   - Document attempted solutions

2. **Notify Escalation Contact**
   - Send email with ticket details
   - Include urgency level
   - Include impact assessment

3. **Handoff**
   - Provide all documentation
   - Explain current state
   - Explain next steps

4. **Follow Up**
   - Monitor resolution progress
   - Update ticket
   - Learn from resolution

---

## Preventive Maintenance

### Daily Tasks

- Check error logs
- Check performance metrics
- Verify critical data accuracy
- Review user feedback

### Weekly Tasks

- Review all metrics
- Analyze trends
- Update documentation
- Train support team

### Monthly Tasks

- Review and update runbook
- Conduct training sessions
- Review incident reports
- Update procedures

---

## Contact Information

### Support Team
- **Support Lead:** [email]
- **Support Team:** [email]

### Development Team
- **Release Manager:** [email]
- **Lead Developer:** [email]
- **Database Administrator:** [email]

### Management
- **CTO:** [email]
- **CEO:** [email]

---

## Appendix: Useful Queries

### Check System Health
```sql
-- Total transactions today
SELECT COUNT(*) FROM sales WHERE DATE(created_at) = CURRENT_DATE;

-- Failed transactions today (if logged)
SELECT COUNT(*) FROM sales WHERE success = false AND DATE(created_at) = CURRENT_DATE;

-- Products with low stock
SELECT name, stock FROM products WHERE stock < 10 ORDER BY stock ASC;

-- Active users today
SELECT COUNT(DISTINCT created_by) FROM sales WHERE DATE(created_at) = CURRENT_DATE;
```

### Check Data Integrity
```sql
-- Stock accuracy
SELECT p.id, p.name, p.stock,
  (SELECT COALESCE(SUM(CASE WHEN sm.type = 'in' THEN sm.quantity ELSE -sm.quantity END), 0)
   FROM stock_movements sm 
   WHERE sm.product_id = p.id) as calculated_stock
FROM products p
WHERE p.stock != calculated_stock;

-- Profit accuracy
SELECT s.id, s.profit,
  (SELECT COALESCE(SUM((si.price - si.cost) * si.quantity), 0)
   FROM sale_items si 
   WHERE si.sale_id = s.id) as calculated_profit
FROM sales s
WHERE s.profit != calculated_profit;
```

### Check Performance
```sql
-- Slow queries (if logged)
SELECT query, mean_exec_time, calls
FROM pg_stat_statements
ORDER BY mean_exec_time DESC
LIMIT 10;

-- Table sizes
SELECT 
  schemaname,
  tablename,
  pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) AS size
FROM pg_tables
WHERE schemaname = 'public'
ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC;
```
