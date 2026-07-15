'use client'

import { useEffect, useState } from 'react'
import { useAuth } from '@/contexts/AuthContext'
import { useRouter } from 'next/navigation'
import { Sidebar } from '@/components/Sidebar'
import { MobileNavigation } from '@/components/MobileNavigation'
import { ProtectedRoute } from '@/components/ProtectedRoute'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { supabase } from '@/lib/supabase'
import { Settings, Save } from 'lucide-react'

interface Setting {
  id: string
  key: string
  value: string
  description: string | null
}

export default function GeneralSettingsPage() {
  const { user, loading } = useAuth()
  const router = useRouter()
  const [settings, setSettings] = useState<Setting[]>([])
  const [formData, setFormData] = useState({
    store_name: '',
    low_stock_threshold: '10'
  })
  const [isSaving, setIsSaving] = useState(false)

  useEffect(() => {
    if (!loading && !user) {
      router.push('/login')
    }
  }, [user, loading, router])

  useEffect(() => {
    if (user) {
      fetchSettings()
    }
  }, [user])

  const fetchSettings = async () => {
    try {
      const { data, error } = await supabase
        .from('settings')
        .select('*')
      
      if (error) throw error
      setSettings(data || [])
      
      // Populate form with existing values
      const storeNameSetting = data?.find(s => s.key === 'store_name')
      const lowStockSetting = data?.find(s => s.key === 'low_stock_threshold')
      
      setFormData({
        store_name: storeNameSetting?.value || 'Kenaya Yummy',
        low_stock_threshold: lowStockSetting?.value || '10'
      })
    } catch (error) {
      console.error('Error fetching settings:', error)
    }
  }

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    setIsSaving(true)
    
    try {
      // Update or insert store_name
      const storeNameSetting = settings.find(s => s.key === 'store_name')
      if (storeNameSetting) {
        await supabase
          .from('settings')
          .update({ value: formData.store_name })
          .eq('id', storeNameSetting.id)
      } else {
        await supabase
          .from('settings')
          .insert({
            key: 'store_name',
            value: formData.store_name,
            description: 'Store/Brand name for display and reports'
          })
      }

      // Update or insert low_stock_threshold
      const lowStockSetting = settings.find(s => s.key === 'low_stock_threshold')
      if (lowStockSetting) {
        await supabase
          .from('settings')
          .update({ value: formData.low_stock_threshold })
          .eq('id', lowStockSetting.id)
      } else {
        await supabase
          .from('settings')
          .insert({
            key: 'low_stock_threshold',
            value: formData.low_stock_threshold,
            description: 'Minimum stock level to trigger low stock alert'
          })
      }

      alert('Pengaturan berhasil disimpan!')
      fetchSettings()
    } catch (error) {
      console.error('Error saving settings:', error)
      alert('Terjadi kesalahan saat menyimpan pengaturan')
    } finally {
      setIsSaving(false)
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
              <h1 className="text-2xl md:text-3xl font-bold text-gray-800">Pengaturan Umum</h1>
              <p className="text-gray-600 mt-1 text-sm md:text-base">Konfigurasi pengaturan sistem</p>
            </div>

            <Card className="shadow-lg max-w-2xl">
              <CardHeader>
                <CardTitle className="flex items-center gap-2">
                  <Settings className="w-5 h-5 text-orange-500" />
                  Pengaturan Sistem
                </CardTitle>
              </CardHeader>
              <CardContent>
                <form onSubmit={handleSubmit} className="space-y-6">
                  <div>
                    <label className="text-sm font-medium text-gray-700 mb-2 block">
                      Nama Toko/Brand
                    </label>
                    <Input
                      value={formData.store_name}
                      onChange={(e) => setFormData({ ...formData, store_name: e.target.value })}
                      placeholder="Masukkan nama toko atau brand"
                      required
                    />
                    <p className="text-xs text-gray-500 mt-1">
                      Nama ini akan ditampilkan di aplikasi dan laporan
                    </p>
                  </div>

                  <div>
                    <label className="text-sm font-medium text-gray-700 mb-2 block">
                      Threshold Stok Rendah
                    </label>
                    <Input
                      type="number"
                      value={formData.low_stock_threshold}
                      onChange={(e) => setFormData({ ...formData, low_stock_threshold: e.target.value })}
                      placeholder="Masukkan angka threshold"
                      min="1"
                      required
                    />
                    <p className="text-xs text-gray-500 mt-1">
                      Produk dengan stok di bawah angka ini akan ditandai sebagai stok rendah
                    </p>
                  </div>

                  <Button
                    type="submit"
                    className="w-full h-12 bg-gradient-to-r from-orange-500 to-red-500 hover:from-orange-600 hover:to-red-600 text-white font-semibold shadow-md"
                    disabled={isSaving}
                  >
                    <Save className="w-4 h-4 mr-2" />
                    {isSaving ? 'Menyimpan...' : 'Simpan Pengaturan'}
                  </Button>
                </form>
              </CardContent>
            </Card>

            <Card className="shadow-lg max-w-2xl mt-6">
              <CardHeader>
                <CardTitle>Pengaturan Lainnya</CardTitle>
              </CardHeader>
              <CardContent>
                <div className="space-y-3">
                  <a href="/settings/categories" className="block p-4 bg-white rounded-lg border border-gray-200 hover:bg-gray-50 transition-colors">
                    <h3 className="font-semibold text-gray-800">Kelola Kategori Produk</h3>
                    <p className="text-sm text-gray-500">Tambah, edit, atau hapus kategori produk</p>
                  </a>
                  <a href="/settings/payment-methods" className="block p-4 bg-white rounded-lg border border-gray-200 hover:bg-gray-50 transition-colors">
                    <h3 className="font-semibold text-gray-800">Kelola Metode Pembayaran</h3>
                    <p className="text-sm text-gray-500">Tambah, edit, atau hapus metode pembayaran</p>
                  </a>
                </div>
              </CardContent>
            </Card>
          </div>
        </main>
        <MobileNavigation />
      </div>
    </ProtectedRoute>
  )
}
