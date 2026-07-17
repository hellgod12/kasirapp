# CRUD Bug List

**Date:** July 18, 2026  
**Scope:** Products, Categories, Customers, Suppliers, Sales, Inventory

---

## Supabase Client Refactoring

**Status:** ✅ COMPLETED  
**Findings:**
- Found 5 `createClient()` calls across 2 files
- `src/lib/supabase.ts` - Singleton pattern (correct)
- `src/lib/auth-debug.ts` - Was creating duplicate clients
- **Fix Applied:** Refactored `auth-debug.ts` to use singleton from `supabase.ts`
- **Result:** All pages now use single singleton Supabase client

---

## Bug List

### BUG-001: Categories Hard Delete Violates Data Integrity
**Severity:** HIGH  
**Location:** `src/app/settings/categories/page.tsx:137-150`  
**Impact:** Deleting categories referenced by products causes FK violations

**Code:**
```typescript
const handleDelete = async (id: string) => {
  if (!confirm('Apakah Anda yakin ingin menghapus kategori ini?')) return
  
  try {
    const { error } = await supabase
      .from('categories')
      .delete()
      .eq('id', id)
    
    if (error) throw error
    fetchCategories()
  } catch (error) {
    alert('Terjadi kesalahan saat menghapus kategori')
  }
}
```

**Issue:** Hard delete without checking if products reference this category. Database has FK constraint from `products.category` to `categories.name` (not ID), but deleting category can still break product categorization.

**Fix Required:** Implement soft delete (`is_active = false`) or check for dependent products before deletion.

---

### BUG-002: Customers Hard Delete Violates Sales FK
**Severity:** HIGH  
**Location:** `src/app/customers/page.tsx:147-160`  
**Impact:** Deleting customers referenced in sales causes data loss

**Code:**
```typescript
const handleDelete = async (id: string) => {
  if (!confirm('Apakah Anda yakin ingin menghapus pelanggan ini?')) return
  
  try {
    const { error } = await supabase
      .from('customers')
      .delete()
      .eq('id', id)
    
    if (error) throw error
    fetchCustomers()
  } catch (error) {
    alert('Terjadi kesalahan saat menghapus pelanggan')
  }
}
```

**Issue:** Hard delete without checking if sales reference this customer. Database has FK constraint from `sales.customer_id` to `customers.id`.

**Fix Required:** Implement soft delete (`is_active = false`) or check for dependent sales before deletion.

---

### BUG-003: Suppliers Hard Delete Violates Data Integrity
**Severity:** MEDIUM  
**Location:** `src/app/suppliers/page.tsx:113-127`  
**Impact:** Deleting suppliers may break inventory tracking

**Code:**
```typescript
const handleDelete = async (id: string) => {
  if (!confirm('Apakah Anda yakin ingin menghapus supplier ini?')) return
  
  try {
    const { error } = await supabase
      .from('suppliers')
      .delete()
      .eq('id', id)
    
    if (error) throw error
    fetchSuppliers()
  } catch (error) {
    alert('Terjadi kesalahan saat menghapus supplier')
  }
}
```

**Issue:** Hard delete without checking for dependencies. While suppliers table has no direct FKs, supplier information may be referenced in inventory records or notes.

**Fix Required:** Implement soft delete (`is_active = false`) or add dependency checking.

---

### BUG-004: No Pagination on Large Datasets
**Severity:** MEDIUM  
**Location:** All CRUD pages  
**Impact:** Performance issues with large datasets

**Affected Pages:**
- `src/app/inventory/products/page.tsx`
- `src/app/settings/categories/page.tsx`
- `src/app/customers/page.tsx`
- `src/app/suppliers/page.tsx`

**Issue:** All pages fetch all records with `.select('*')` without pagination. With hundreds/thousands of records, this will cause:
- Slow page loads
- High memory usage
- Network timeouts

**Fix Required:** Implement Supabase pagination with `.range()` or infinite scroll.

---

### BUG-005: Stock Update Race Condition
**Severity:** HIGH  
**Location:** `src/app/inventory/stock-in/page.tsx:74-90`  
**Impact:** Concurrent stock updates can cause data inconsistency

**Code:**
```typescript
// Fetch current stock from database to avoid stale data
const { data: currentProduct } = await supabase
  .from('products')
  .select('stock')
  .eq('id', selectedProduct)
  .single()

if (!currentProduct) {
  alert('Produk tidak ditemukan')
  return
}

// Update product stock using current database value
const { error: updateError } = await supabase
  .from('products')
  .update({ stock: currentProduct.stock + qty })
  .eq('id', selectedProduct)
```

**Issue:** Read-then-write pattern without transaction. If two users update stock simultaneously:
1. User A reads stock: 10
2. User B reads stock: 10
3. User A updates to 15 (+5)
4. User B updates to 12 (+2)
5. Final stock: 12 (should be 17)

**Fix Required:** Use database-level atomic increment or PostgreSQL transaction.

---

### BUG-006: Products Barcode Not Unique on Insert
**Severity:** MEDIUM  
**Location:** `src/app/inventory/products/page.tsx:166-171`  
**Impact:** Duplicate barcodes can cause POS conflicts

**Code:**
```typescript
} else {
  const { error } = await supabase
    .from('products')
    .insert(productData)
  
  if (error) throw error
}
```

**Issue:** No validation for duplicate barcode before insert. Database has unique constraint on barcode, but error handling only shows generic alert.

**Fix Required:** Check for existing barcode before insert and show specific error message.

---

### BUG-007: No Search by Barcode in Products
**Severity:** LOW  
**Location:** `src/app/inventory/products/page.tsx:227-231`  
**Impact:** Cannot search products by barcode

**Code:**
```typescript
const filteredProducts = products.filter(product => {
  const matchesSearch = product.name.toLowerCase().includes(searchQuery.toLowerCase())
  const matchesCategory = filterCategory === 'all' || product.category === filterCategory
  return matchesSearch && matchesCategory
})
```

**Issue:** Search only checks product name, not barcode. Barcode field exists but not searchable.

**Fix Required:** Add barcode to search filter.

---

### BUG-008: Customer Balance Update Not Atomic
**Severity:** HIGH  
**Location:** `src/app/pos/page.tsx` (via RPC)  
**Impact:** Concurrent customer balance updates can cause incorrect balances

**Code:** The `process_checkout` RPC function updates customer balance:
```sql
UPDATE customers
SET balance = balance + v_final_amount,
    updated_at = NOW()
WHERE id = p_customer_id AND is_active = true;
```

**Issue:** Direct update without atomic increment. Race condition possible with concurrent checkouts.

**Fix Required:** Use atomic increment or row-level locking.

---

### BUG-009: No Validation for Negative Stock
**Severity:** MEDIUM  
**Location:** `src/app/inventory/products/page.tsx:143-146`  
**Impact:** Can create products with negative stock

**Code:**
```typescript
if (stock < 0) {
  alert('Stok tidak boleh negatif')
  return
}
```

**Issue:** Validation exists on form submit, but database constraint `products_stock_check` also enforces this. However, the validation message is generic and doesn't guide user.

**Fix Required:** Improve error handling to show constraint violation details.

---

### BUG-010: No Export/Import Functionality
**Severity:** LOW  
**Location:** `src/app/inventory/products/page.tsx:252-256`  
**Impact:** Button exists but functionality not implemented

**Code:**
```typescript
<Button
  variant="outline"
  className="bg-white border-gray-300 hover:bg-gray-50"
  onClick={() => router.push('/inventory/products-import')}
>
  <FileSpreadsheet className="w-4 h-4 mr-2" />
  Import/Export
</Button>
```

**Issue:** Button navigates to `/inventory/products-import` but this route may not exist or be implemented.

**Fix Required:** Implement import/export page or remove button.

---

## Summary

**Total Bugs:** 10  
**High Severity:** 4  
**Medium Severity:** 4  
**Low Severity:** 2  

**Critical Issues:**
1. Categories hard delete (BUG-001)
2. Customers hard delete (BUG-002)
3. Stock update race condition (BUG-005)
4. Customer balance update not atomic (BUG-008)

**Recommended Priority:**
1. Fix BUG-005 (stock race condition) - data integrity
2. Fix BUG-008 (balance race condition) - financial accuracy
3. Fix BUG-001, BUG-002 (hard deletes) - data integrity
4. Fix BUG-004 (pagination) - performance
5. Fix remaining bugs as needed
