'use client'

import { useEffect, useState } from 'react'
import { useAuth } from '@/contexts/AuthContext'
import { useRouter } from 'next/navigation'
import { Sidebar } from '@/components/Sidebar'
import { MobileNavigation } from '@/components/MobileNavigation'
import { ProtectedRoute } from '@/components/ProtectedRoute'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card'
import { Button } from '@/components/ui/button'
import { supabase } from '@/lib/supabase'
import { Download, Upload, Database, FileJson, AlertTriangle } from 'lucide-react'

export default function BackupPage() {
  const { user, loading } = useAuth()
  const router = useRouter()
  const [isExporting, setIsExporting] = useState(false)
  const [isImporting, setIsImporting] = useState(false)

  useEffect(() => {
    if (!loading && !user) {
      router.push('/login')
    }
  }, [user, loading, router])

  const exportData = async () => {
    setIsExporting(true)
    try {
      // Fetch all data
      const [products, customers, suppliers, categories, paymentMethods, discounts] = await Promise.all([
        supabase.from('products').select('*'),
        supabase.from('customers').select('*'),
        supabase.from('suppliers').select('*'),
        supabase.from('categories').select('*'),
        supabase.from('payment_methods').select('*'),
        supabase.from('discounts').select('*')
      ])

      const backupData = {
        export_date: new Date().toISOString(),
        products: products.data || [],
        customers: customers.data || [],
        suppliers: suppliers.data || [],
        categories: categories.data || [],
        payment_methods: paymentMethods.data || [],
        discounts: discounts.data || []
      }

      // Create and download JSON file
      const blob = new Blob([JSON.stringify(backupData, null, 2)], { type: 'application/json' })
      const url = URL.createObjectURL(blob)
      const a = document.createElement('a')
      a.href = url
      a.download = `kasirapp-backup-${new Date().toISOString().split('T')[0]}.json`
      document.body.appendChild(a)
      a.click()
      document.body.removeChild(a)
      URL.revokeObjectURL(url)

      alert('Backup berhasil diunduh!')
    } catch (error) {
      alert('Terjadi kesalahan saat melakukan backup')
    } finally {
      setIsExporting(false)
    }
  }

  const importData = async (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0]
    if (!file) return

    setIsImporting(true)
    try {
      const text = await file.text()
      const data = JSON.parse(text)

      // Validate data structure
      if (!data.products || !data.customers || !data.suppliers) {
        throw new Error('Format file tidak valid')
      }

      // Import products
      if (data.products.length > 0) {
        for (const product of data.products) {
          const { id, created_at, updated_at, ...productData } = product
          await supabase.from('products').upsert(productData)
        }
      }

      // Import customers
      if (data.customers.length > 0) {
        for (const customer of data.customers) {
          const { id, created_at, updated_at, ...customerData } = customer
          await supabase.from('customers').upsert(customerData)
        }
      }

      // Import suppliers
      if (data.suppliers.length > 0) {
        for (const supplier of data.suppliers) {
          const { id, created_at, ...supplierData } = supplier
          await supabase.from('suppliers').upsert(supplierData)
        }
      }

      // Import categories
      if (data.categories && data.categories.length > 0) {
        for (const category of data.categories) {
          const { id, created_at, ...categoryData } = category
          await supabase.from('categories').upsert(categoryData)
        }
      }

      // Import payment methods
      if (data.payment_methods && data.payment_methods.length > 0) {
        for (const pm of data.payment_methods) {
          const { id, created_at, ...pmData } = pm
          await supabase.from('payment_methods').upsert(pmData)
        }
      }

      // Import discounts
      if (data.discounts && data.discounts.length > 0) {
        for (const discount of data.discounts) {
          const { id, created_at, updated_at, ...discountData } = discount
          await supabase.from('discounts').upsert(discountData)
        }
      }

      alert('Restore berhasil!')
    } catch (error) {
      alert('Terjadi kesalahan saat melakukan restore. Pastikan file format valid.')
    } finally {
      setIsImporting(false)
      e.target.value = ''
    }
  }

  if (loading || !user) {
    return null
  }

  return (
    <ProtectedRoute allowedRoles={['admin']}>
      <div className="flex h-screen bg-gray-50">
        <Sidebar />
        <main className="flex-1 overflow-auto pb-20 md:pb-0">
          <div className="p-4 md:p-8">
            <div className="mb-6 md:mb-8">
              <h1 className="text-2xl md:text-3xl font-bold text-gray-800">Backup & Restore</h1>
              <p className="text-gray-600 mt-1 text-sm md:text-base">Kelola backup data aplikasi</p>
            </div>

            <div className="space-y-6">
              {/* Export Section */}
              <Card className="shadow-lg">
                <CardHeader>
                  <CardTitle className="flex items-center gap-2">
                    <Download className="w-5 h-5 text-green-500" />
                    Export Data (Backup)
                  </CardTitle>
                </CardHeader>
                <CardContent>
                  <div className="space-y-4">
                    <p className="text-gray-600">
                      Download semua data penting (produk, pelanggan, supplier, kategori, metode pembayaran, diskon) dalam format JSON.
                    </p>
                    <div className="flex flex-wrap gap-2">
                      <Button
                        onClick={exportData}
                        disabled={isExporting}
                        className="bg-gradient-to-r from-green-500 to-emerald-500 hover:from-green-600 hover:to-emerald-600"
                      >
                        <FileJson className="w-4 h-4 mr-2" />
                        {isExporting ? 'Mengekspor...' : 'Export Data'}
                      </Button>
                    </div>
                  </div>
                </CardContent>
              </Card>

              {/* Import Section */}
              <Card className="shadow-lg">
                <CardHeader>
                  <CardTitle className="flex items-center gap-2">
                    <Upload className="w-5 h-5 text-blue-500" />
                    Import Data (Restore)
                  </CardTitle>
                </CardHeader>
                <CardContent>
                  <div className="space-y-4">
                    <p className="text-gray-600">
                      Upload file backup JSON untuk memulihkan data. Data yang ada akan diperbarui atau ditambahkan.
                    </p>
                    <div className="bg-yellow-50 border border-yellow-200 rounded-lg p-4">
                      <div className="flex items-start gap-3">
                        <AlertTriangle className="w-5 h-5 text-yellow-600 mt-0.5" />
                        <div className="text-sm text-yellow-800">
                          <p className="font-semibold mb-1">Peringatan:</p>
                          <p>Restore akan menimpa data yang ada dengan data dari file backup. Pastikan Anda memiliki backup terbaru sebelum melakukan restore.</p>
                        </div>
                      </div>
                    </div>
                    <div>
                      <input
                        type="file"
                        accept=".json"
                        onChange={importData}
                        disabled={isImporting}
                        className="hidden"
                        id="import-file"
                      />
                      <label htmlFor="import-file">
                        <Button
                          disabled={isImporting}
                          className="bg-gradient-to-r from-blue-500 to-indigo-500 hover:from-blue-600 hover:to-indigo-600 cursor-pointer w-full"
                        >
                          <Database className="w-4 h-4 mr-2" />
                          {isImporting ? 'Mengimpor...' : 'Import Data'}
                        </Button>
                      </label>
                    </div>
                  </div>
                </CardContent>
              </Card>

              {/* Info Section */}
              <Card className="shadow-lg">
                <CardHeader>
                  <CardTitle>Informasi Backup</CardTitle>
                </CardHeader>
                <CardContent>
                  <div className="space-y-3 text-sm text-gray-600">
                    <p><strong>Yang termasuk dalam backup:</strong></p>
                    <ul className="list-disc list-inside space-y-1 ml-2">
                      <li>Produk (nama, kategori, harga, stok, barcode)</li>
                      <li>Pelanggan (nama, kontak, saldo, poin)</li>
                      <li>Supplier (nama, kontak, alamat)</li>
                      <li>Kategori produk</li>
                      <li>Metode pembayaran</li>
                      <li>Diskon dan promo</li>
                    </ul>
                    <p className="mt-4"><strong>Yang TIDAK termasuk:</strong></p>
                    <ul className="list-disc list-inside space-y-1 ml-2">
                      <li>Riwayat transaksi penjualan</li>
                      <li>Riwayat stok movement</li>
                      <li>Data pengguna (user accounts)</li>
                      <li>Pengaturan sistem</li>
                    </ul>
                    <p className="mt-4">
                      <strong>Catatan:</strong> Untuk backup lengkap termasuk transaksi, gunakan fitur backup di Supabase Dashboard.
                    </p>
                  </div>
                </CardContent>
              </Card>
            </div>
          </div>
        </main>
        <MobileNavigation />
      </div>
    </ProtectedRoute>
  )
}
