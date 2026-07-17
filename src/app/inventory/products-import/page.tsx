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
import { Download, Upload, FileSpreadsheet, AlertTriangle, CheckCircle } from 'lucide-react'
import * as XLSX from 'xlsx'

interface Product {
  id: string
  name: string
  category: string
  price: number
  cost: number
  stock: number
  barcode: string | null
}

export default function ProductsImportPage() {
  const { user, loading } = useAuth()
  const router = useRouter()
  const [isExporting, setIsExporting] = useState(false)
  const [isImporting, setIsImporting] = useState(false)
  const [importResults, setImportResults] = useState<{ success: number; failed: number; errors: string[] } | null>(null)

  useEffect(() => {
    if (!loading && !user) {
      router.push('/login')
    }
  }, [user, loading, router])

  const exportProducts = async () => {
    setIsExporting(true)
    try {
      const { data, error } = await supabase
        .from('products')
        .select('*')
        .eq('is_active', true)
        .order('name')
      
      if (error) throw error

      // Format data for Excel
      const excelData = (data || []).map((product: Product) => ({
        'Nama Produk': product.name,
        'Kategori': product.category,
        'Harga Jual': product.price,
        'Harga Modal': product.cost,
        'Stok': product.stock,
        'Barcode': product.barcode || ''
      }))

      // Create worksheet
      const ws = XLSX.utils.json_to_sheet(excelData)
      const wb = XLSX.utils.book_new()
      XLSX.utils.book_append_sheet(wb, ws, 'Produk')

      // Download file
      XLSX.writeFile(wb, `kasirapp-products-${new Date().toISOString().split('T')[0]}.xlsx`)

      alert('Export berhasil!')
    } catch (error) {
      alert('Terjadi kesalahan saat melakukan export')
    } finally {
      setIsExporting(false)
    }
  }

  const importProducts = async (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0]
    if (!file) return

    setIsImporting(true)
    setImportResults(null)
    
    try {
      const data = await file.arrayBuffer()
      const workbook = XLSX.read(data)
      const worksheet = workbook.Sheets[workbook.SheetNames[0]]
      const jsonData = XLSX.utils.sheet_to_json(worksheet)

      let successCount = 0
      let failedCount = 0
      const errors: string[] = []

      for (const row of jsonData as any) {
        try {
          const productData = {
            name: row['Nama Produk'] || row['name'],
            category: row['Kategori'] || row['category'],
            price: parseFloat(row['Harga Jual'] || row['price'] || 0),
            cost: parseFloat(row['Harga Modal'] || row['cost'] || 0),
            stock: parseInt(row['Stok'] || row['stock'] || 0),
            barcode: row['Barcode'] || row['barcode'] || null
          }

          // Validate
          if (!productData.name) {
            throw new Error('Nama produk wajib diisi')
          }
          if (!productData.category) {
            throw new Error('Kategori wajib diisi')
          }
          if (productData.price <= 0) {
            throw new Error('Harga jual harus lebih dari 0')
          }
          if (productData.cost < 0) {
            throw new Error('Harga modal tidak boleh negatif')
          }
          if (productData.stock < 0) {
            throw new Error('Stok tidak boleh negatif')
          }

          // Check if category exists
          const { data: categoryData } = await supabase
            .from('categories')
            .select('name')
            .eq('name', productData.category)
            .single()

          if (!categoryData) {
            throw new Error(`Kategori "${productData.category}" tidak ditemukan`)
          }

          // Upsert product
          const { error: upsertError } = await supabase
            .from('products')
            .upsert({
              name: productData.name,
              category: productData.category,
              price: productData.price,
              cost: productData.cost,
              stock: productData.stock,
              barcode: productData.barcode,
              is_active: true
            }, {
              onConflict: 'name'
            })

          if (upsertError) throw upsertError

          successCount++
        } catch (error: any) {
          failedCount++
          errors.push(`${row['Nama Produk'] || 'Unknown'}: ${error.message}`)
        }
      }

      setImportResults({ success: successCount, failed: failedCount, errors })
      
      if (successCount > 0) {
        alert(`Import selesai! ${successCount} produk berhasil, ${failedCount} gagal.`)
      } else {
        alert('Import gagal. Tidak ada produk yang berhasil diimpor.')
      }
    } catch (error) {
      alert('Terjadi kesalahan saat membaca file Excel. Pastikan format file valid.')
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
              <h1 className="text-2xl md:text-3xl font-bold text-gray-800">Import/Export Produk</h1>
              <p className="text-gray-600 mt-1 text-sm md:text-base">Kelola produk dalam jumlah banyak menggunakan Excel</p>
            </div>

            <div className="space-y-6">
              {/* Export Section */}
              <Card className="shadow-lg">
                <CardHeader>
                  <CardTitle className="flex items-center gap-2">
                    <Download className="w-5 h-5 text-green-500" />
                    Export Produk ke Excel
                  </CardTitle>
                </CardHeader>
                <CardContent>
                  <div className="space-y-4">
                    <p className="text-gray-600">
                      Download semua produk aktif ke format Excel untuk editing atau backup.
                    </p>
                    <Button
                      onClick={exportProducts}
                      disabled={isExporting}
                      className="bg-gradient-to-r from-green-500 to-emerald-500 hover:from-green-600 hover:to-emerald-600"
                    >
                      <FileSpreadsheet className="w-4 h-4 mr-2" />
                      {isExporting ? 'Mengekspor...' : 'Export Excel'}
                    </Button>
                  </div>
                </CardContent>
              </Card>

              {/* Import Section */}
              <Card className="shadow-lg">
                <CardHeader>
                  <CardTitle className="flex items-center gap-2">
                    <Upload className="w-5 h-5 text-blue-500" />
                    Import Produk dari Excel
                  </CardTitle>
                </CardHeader>
                <CardContent>
                  <div className="space-y-4">
                    <p className="text-gray-600">
                      Upload file Excel untuk menambah atau mengupdate produk dalam jumlah banyak.
                    </p>
                    
                    <div className="bg-blue-50 border border-blue-200 rounded-lg p-4">
                      <div className="flex items-start gap-3">
                        <CheckCircle className="w-5 h-5 text-blue-600 mt-0.5" />
                        <div className="text-sm text-blue-800">
                          <p className="font-semibold mb-1">Format Excel:</p>
                          <p>Kolom yang diperlukan: Nama Produk, Kategori, Harga Jual, Harga Modal, Stok, Barcode (opsional)</p>
                        </div>
                      </div>
                    </div>

                    <div className="bg-yellow-50 border border-yellow-200 rounded-lg p-4">
                      <div className="flex items-start gap-3">
                        <AlertTriangle className="w-5 h-5 text-yellow-600 mt-0.5" />
                        <div className="text-sm text-yellow-800">
                          <p className="font-semibold mb-1">Catatan:</p>
                          <ul className="list-disc list-inside space-y-1">
                            <li>Kategori harus sudah ada di sistem</li>
                            <li>Produk dengan nama yang sama akan diupdate</li>
                            <li>Produk baru akan ditambahkan</li>
                          </ul>
                        </div>
                      </div>
                    </div>

                    <div>
                      <input
                        type="file"
                        accept=".xlsx,.xls"
                        onChange={importProducts}
                        disabled={isImporting}
                        className="hidden"
                        id="import-file"
                      />
                      <label htmlFor="import-file">
                        <Button
                          disabled={isImporting}
                          className="bg-gradient-to-r from-blue-500 to-indigo-500 hover:from-blue-600 hover:to-indigo-600 cursor-pointer w-full"
                        >
                          <FileSpreadsheet className="w-4 h-4 mr-2" />
                          {isImporting ? 'Mengimpor...' : 'Import Excel'}
                        </Button>
                      </label>
                    </div>

                    {importResults && (
                      <div className="mt-4 p-4 bg-gray-50 rounded-lg border">
                        <h4 className="font-semibold mb-2">Hasil Import:</h4>
                        <div className="flex gap-4 text-sm">
                          <span className="text-green-600">Berhasil: {importResults.success}</span>
                          <span className="text-red-600">Gagal: {importResults.failed}</span>
                        </div>
                        {importResults.errors.length > 0 && (
                          <div className="mt-2">
                            <p className="font-semibold text-sm mb-1">Error:</p>
                            <ul className="text-xs text-red-600 list-disc list-inside space-y-1">
                              {importResults.errors.slice(0, 5).map((error, i) => (
                                <li key={i}>{error}</li>
                              ))}
                              {importResults.errors.length > 5 && (
                                <li>... dan {importResults.errors.length - 5} error lainnya</li>
                              )}
                            </ul>
                          </div>
                        )}
                      </div>
                    )}
                  </div>
                </CardContent>
              </Card>

              {/* Template Download */}
              <Card className="shadow-lg">
                <CardHeader>
                  <CardTitle>Download Template</CardTitle>
                </CardHeader>
                <CardContent>
                  <p className="text-gray-600 mb-4">
                    Download template Excel untuk memastikan format yang benar.
                  </p>
                  <Button
                    onClick={exportProducts}
                    variant="outline"
                    className="w-full"
                  >
                    <FileSpreadsheet className="w-4 h-4 mr-2" />
                    Download Template
                  </Button>
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
