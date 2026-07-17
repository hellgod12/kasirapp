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
    store_address: '',
    store_phone: '',
    store_email: '',
    store_logo_url: '',
    low_stock_threshold: '10',
    tax_enabled: 'false',
    tax_rate: '11',
    tax_name: 'PPN',
    receipt_header: 'TERIMA KASIH',
    receipt_footer: 'Barang yang sudah dibeli tidak dapat ditukar/dikembalikan'
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
      const storeAddressSetting = data?.find(s => s.key === 'store_address')
      const storePhoneSetting = data?.find(s => s.key === 'store_phone')
      const storeEmailSetting = data?.find(s => s.key === 'store_email')
      const storeLogoUrlSetting = data?.find(s => s.key === 'store_logo_url')
      const lowStockSetting = data?.find(s => s.key === 'low_stock_threshold')
      const taxEnabledSetting = data?.find(s => s.key === 'tax_enabled')
      const taxRateSetting = data?.find(s => s.key === 'tax_rate')
      const taxNameSetting = data?.find(s => s.key === 'tax_name')
      const receiptHeaderSetting = data?.find(s => s.key === 'receipt_header')
      const receiptFooterSetting = data?.find(s => s.key === 'receipt_footer')
      
      setFormData({
        store_name: storeNameSetting?.value || 'KasirApp',
        store_address: storeAddressSetting?.value || '',
        store_phone: storePhoneSetting?.value || '',
        store_email: storeEmailSetting?.value || '',
        store_logo_url: storeLogoUrlSetting?.value || '',
        low_stock_threshold: lowStockSetting?.value || '10',
        tax_enabled: taxEnabledSetting?.value || 'false',
        tax_rate: taxRateSetting?.value || '11',
        tax_name: taxNameSetting?.value || 'PPN',
        receipt_header: receiptHeaderSetting?.value || 'TERIMA KASIH',
        receipt_footer: receiptFooterSetting?.value || 'Barang yang sudah dibeli tidak dapat ditukar/dikembalikan'
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

      // Update or insert store_address
      const storeAddressSetting = settings.find(s => s.key === 'store_address')
      if (storeAddressSetting) {
        await supabase
          .from('settings')
          .update({ value: formData.store_address })
          .eq('id', storeAddressSetting.id)
      } else {
        await supabase
          .from('settings')
          .insert({
            key: 'store_address',
            value: formData.store_address,
            description: 'Store physical address'
          })
      }

      // Update or insert store_phone
      const storePhoneSetting = settings.find(s => s.key === 'store_phone')
      if (storePhoneSetting) {
        await supabase
          .from('settings')
          .update({ value: formData.store_phone })
          .eq('id', storePhoneSetting.id)
      } else {
        await supabase
          .from('settings')
          .insert({
            key: 'store_phone',
            value: formData.store_phone,
            description: 'Store contact phone number'
          })
      }

      // Update or insert store_email
      const storeEmailSetting = settings.find(s => s.key === 'store_email')
      if (storeEmailSetting) {
        await supabase
          .from('settings')
          .update({ value: formData.store_email })
          .eq('id', storeEmailSetting.id)
      } else {
        await supabase
          .from('settings')
          .insert({
            key: 'store_email',
            value: formData.store_email,
            description: 'Store contact email'
          })
      }

      // Update or insert store_logo_url
      const storeLogoUrlSetting = settings.find(s => s.key === 'store_logo_url')
      if (storeLogoUrlSetting) {
        await supabase
          .from('settings')
          .update({ value: formData.store_logo_url })
          .eq('id', storeLogoUrlSetting.id)
      } else {
        await supabase
          .from('settings')
          .insert({
            key: 'store_logo_url',
            value: formData.store_logo_url,
            description: 'Store logo image URL'
          })
      }

      // Update or insert receipt_header
      const receiptHeaderSetting = settings.find(s => s.key === 'receipt_header')
      if (receiptHeaderSetting) {
        await supabase
          .from('settings')
          .update({ value: formData.receipt_header })
          .eq('id', receiptHeaderSetting.id)
      } else {
        await supabase
          .from('settings')
          .insert({
            key: 'receipt_header',
            value: formData.receipt_header,
            description: 'Receipt header text'
          })
      }

      // Update or insert receipt_footer
      const receiptFooterSetting = settings.find(s => s.key === 'receipt_footer')
      if (receiptFooterSetting) {
        await supabase
          .from('settings')
          .update({ value: formData.receipt_footer })
          .eq('id', receiptFooterSetting.id)
      } else {
        await supabase
          .from('settings')
          .insert({
            key: 'receipt_footer',
            value: formData.receipt_footer,
            description: 'Receipt footer text'
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

      // Update or insert tax_enabled
      const taxEnabledSetting = settings.find(s => s.key === 'tax_enabled')
      if (taxEnabledSetting) {
        await supabase
          .from('settings')
          .update({ value: formData.tax_enabled })
          .eq('id', taxEnabledSetting.id)
      } else {
        await supabase
          .from('settings')
          .insert({
            key: 'tax_enabled',
            value: formData.tax_enabled,
            description: 'Enable/disable tax calculation'
          })
      }

      // Update or insert tax_rate
      const taxRateSetting = settings.find(s => s.key === 'tax_rate')
      if (taxRateSetting) {
        await supabase
          .from('settings')
          .update({ value: formData.tax_rate })
          .eq('id', taxRateSetting.id)
      } else {
        await supabase
          .from('settings')
          .insert({
            key: 'tax_rate',
            value: formData.tax_rate,
            description: 'Tax rate percentage'
          })
      }

      // Update or insert tax_name
      const taxNameSetting = settings.find(s => s.key === 'tax_name')
      if (taxNameSetting) {
        await supabase
          .from('settings')
          .update({ value: formData.tax_name })
          .eq('id', taxNameSetting.id)
      } else {
        await supabase
          .from('settings')
          .insert({
            key: 'tax_name',
            value: formData.tax_name,
            description: 'Tax name for display (e.g., PPN, VAT)'
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
                      Alamat Toko
                    </label>
                    <Input
                      value={formData.store_address}
                      onChange={(e) => setFormData({ ...formData, store_address: e.target.value })}
                      placeholder="Masukkan alamat toko"
                    />
                    <p className="text-xs text-gray-500 mt-1">
                      Alamat fisik toko untuk struk dan laporan
                    </p>
                  </div>

                  <div>
                    <label className="text-sm font-medium text-gray-700 mb-2 block">
                      No. Telepon Toko
                    </label>
                    <Input
                      value={formData.store_phone}
                      onChange={(e) => setFormData({ ...formData, store_phone: e.target.value })}
                      placeholder="Masukkan nomor telepon"
                    />
                    <p className="text-xs text-gray-500 mt-1">
                      Nomor kontak untuk struk dan laporan
                    </p>
                  </div>

                  <div>
                    <label className="text-sm font-medium text-gray-700 mb-2 block">
                      Email Toko
                    </label>
                    <Input
                      type="email"
                      value={formData.store_email}
                      onChange={(e) => setFormData({ ...formData, store_email: e.target.value })}
                      placeholder="Masukkan email"
                    />
                    <p className="text-xs text-gray-500 mt-1">
                      Email kontak untuk struk dan laporan
                    </p>
                  </div>

                  <div>
                    <label className="text-sm font-medium text-gray-700 mb-2 block">
                      URL Logo Toko
                    </label>
                    <Input
                      value={formData.store_logo_url}
                      onChange={(e) => setFormData({ ...formData, store_logo_url: e.target.value })}
                      placeholder="https://example.com/logo.png"
                    />
                    <p className="text-xs text-gray-500 mt-1">
                      URL gambar logo untuk struk dan laporan (opsional)
                    </p>
                  </div>

                  <div className="border-t border-gray-200 pt-6">
                    <h3 className="text-lg font-semibold text-gray-800 mb-4">Pengaturan Struk</h3>
                  </div>

                  <div>
                    <label className="text-sm font-medium text-gray-700 mb-2 block">
                      Header Struk
                    </label>
                    <Input
                      value={formData.receipt_header}
                      onChange={(e) => setFormData({ ...formData, receipt_header: e.target.value })}
                      placeholder="TERIMA KASIH"
                    />
                    <p className="text-xs text-gray-500 mt-1">
                      Teks yang ditampilkan di bagian atas struk
                    </p>
                  </div>

                  <div>
                    <label className="text-sm font-medium text-gray-700 mb-2 block">
                      Footer Struk
                    </label>
                    <Input
                      value={formData.receipt_footer}
                      onChange={(e) => setFormData({ ...formData, receipt_footer: e.target.value })}
                      placeholder="Barang yang sudah dibeli tidak dapat ditukar/dikembalikan"
                    />
                    <p className="text-xs text-gray-500 mt-1">
                      Teks yang ditampilkan di bagian bawah struk
                    </p>
                  </div>

                  <div className="border-t border-gray-200 pt-6">
                    <h3 className="text-lg font-semibold text-gray-800 mb-4">Pengaturan Inventaris</h3>
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

                  <div className="border-t border-gray-200 pt-6">
                    <h3 className="text-lg font-semibold text-gray-800 mb-4">Pengaturan Pajak</h3>
                  </div>

                  <div>
                    <label className="text-sm font-medium text-gray-700 mb-2 block">
                      Nama Pajak
                    </label>
                    <Input
                      value={formData.tax_name}
                      onChange={(e) => setFormData({ ...formData, tax_name: e.target.value })}
                      placeholder="Contoh: PPN, VAT"
                    />
                    <p className="text-xs text-gray-500 mt-1">
                      Nama pajak yang akan ditampilkan di struk dan laporan
                    </p>
                  </div>

                  <div>
                    <label className="text-sm font-medium text-gray-700 mb-2 block">
                      Tarif Pajak (%)
                    </label>
                    <Input
                      type="number"
                      value={formData.tax_rate}
                      onChange={(e) => setFormData({ ...formData, tax_rate: e.target.value })}
                      placeholder="Contoh: 11"
                      min="0"
                      max="100"
                      step="0.01"
                    />
                    <p className="text-xs text-gray-500 mt-1">
                      Persentase pajak yang akan dikenakan pada transaksi
                    </p>
                  </div>

                  <div>
                    <label className="text-sm font-medium text-gray-700 mb-2 block">
                      Aktifkan Pajak
                    </label>
                    <select
                      value={formData.tax_enabled}
                      onChange={(e) => setFormData({ ...formData, tax_enabled: e.target.value })}
                      className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-orange-500"
                    >
                      <option value="false">Nonaktif</option>
                      <option value="true">Aktif</option>
                    </select>
                    <p className="text-xs text-gray-500 mt-1">
                      Jika diaktifkan, pajak akan dihitung secara otomatis pada setiap transaksi
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
