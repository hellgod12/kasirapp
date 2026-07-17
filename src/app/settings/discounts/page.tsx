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
import { Dialog, DialogContent, DialogHeader, DialogTitle, DialogTrigger } from '@/components/ui/dialog'
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select'
import { supabase } from '@/lib/supabase'
import { Plus, Edit, Trash2, Percent, DollarSign, Search, Calendar, ToggleLeft, ToggleRight } from 'lucide-react'

interface Discount {
  id: string
  name: string
  type: 'percentage' | 'fixed'
  value: number
  min_purchase: number
  max_discount: number | null
  is_active: boolean
  valid_from: string
  valid_until: string | null
  created_at: string
}

interface FormData {
  name: string
  type: 'percentage' | 'fixed'
  value: string
  min_purchase: string
  max_discount: string
  valid_from: string
  valid_until: string
}

export default function DiscountsPage() {
  const { user, loading } = useAuth()
  const router = useRouter()
  const [discounts, setDiscounts] = useState<Discount[]>([])
  const [searchQuery, setSearchQuery] = useState('')
  const [isDialogOpen, setIsDialogOpen] = useState(false)
  const [editingDiscount, setEditingDiscount] = useState<Discount | null>(null)
  const [formData, setFormData] = useState<FormData>({
    name: '',
    type: 'percentage',
    value: '',
    min_purchase: '0',
    max_discount: '',
    valid_from: new Date().toISOString().split('T')[0],
    valid_until: ''
  })

  useEffect(() => {
    if (!loading && !user) {
      router.push('/login')
    }
  }, [user, loading, router])

  useEffect(() => {
    if (user) {
      fetchDiscounts()
    }
  }, [user])

  const fetchDiscounts = async () => {
    try {
      const { data, error } = await supabase
        .from('discounts')
        .select('*')
        .order('created_at', { ascending: false })
      
      if (error) throw error
      setDiscounts(data || [])
    } catch (error) {
      // Error will be handled by error boundary
      throw error
    }
  }

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    
    // Validate data
    const value = parseFloat(formData.value)
    const minPurchase = parseFloat(formData.min_purchase)
    const maxDiscount = formData.max_discount ? parseFloat(formData.max_discount) : null
    
    if (value <= 0) {
      alert('Nilai diskon harus lebih dari 0')
      return
    }
    if (formData.type === 'percentage' && value > 100) {
      alert('Persentase diskon tidak boleh lebih dari 100%')
      return
    }
    if (minPurchase < 0) {
      alert('Minimum pembelian tidak boleh negatif')
      return
    }
    if (maxDiscount !== null && maxDiscount < 0) {
      alert('Maksimum diskon tidak boleh negatif')
      return
    }
    
    try {
      const discountData = {
        name: formData.name,
        type: formData.type,
        value,
        min_purchase: minPurchase,
        max_discount: maxDiscount,
        valid_from: formData.valid_from,
        valid_until: formData.valid_until || null
      }

      if (editingDiscount) {
        const { error } = await supabase
          .from('discounts')
          .update(discountData)
          .eq('id', editingDiscount.id)
        
        if (error) throw error
      } else {
        const { error } = await supabase
          .from('discounts')
          .insert(discountData)
        
        if (error) throw error
      }

      setIsDialogOpen(false)
      resetForm()
      fetchDiscounts()
    } catch (error) {
      alert('Terjadi kesalahan saat menyimpan diskon')
    }
  }

  const handleEdit = (discount: Discount) => {
    setEditingDiscount(discount)
    setFormData({
      name: discount.name,
      type: discount.type,
      value: discount.value.toString(),
      min_purchase: discount.min_purchase.toString(),
      max_discount: discount.max_discount?.toString() || '',
      valid_from: discount.valid_from.split('T')[0],
      valid_until: discount.valid_until ? discount.valid_until.split('T')[0] : ''
    })
    setIsDialogOpen(true)
  }

  const handleToggleActive = async (discount: Discount) => {
    try {
      const { error } = await supabase
        .from('discounts')
        .update({ is_active: !discount.is_active })
        .eq('id', discount.id)
      
      if (error) throw error
      fetchDiscounts()
    } catch (error) {
      alert('Terjadi kesalahan saat mengubah status diskon')
    }
  }

  const handleDelete = async (id: string) => {
    if (!confirm('Apakah Anda yakin ingin menghapus diskon ini?')) return
    
    try {
      const { error } = await supabase
        .from('discounts')
        .delete()
        .eq('id', id)
      
      if (error) throw error
      fetchDiscounts()
    } catch (error) {
      alert('Terjadi kesalahan saat menghapus diskon')
    }
  }

  const resetForm = () => {
    setFormData({
      name: '',
      type: 'percentage',
      value: '',
      min_purchase: '0',
      max_discount: '',
      valid_from: new Date().toISOString().split('T')[0],
      valid_until: ''
    })
    setEditingDiscount(null)
  }

  const filteredDiscounts = discounts.filter(discount => {
    const matchesSearch = discount.name.toLowerCase().includes(searchQuery.toLowerCase())
    return matchesSearch
  })

  if (loading || !user) {
    return null
  }

  return (
    <ProtectedRoute allowedRoles={['admin']}>
      <div className="flex h-screen bg-gray-50">
        <Sidebar />
        <main className="flex-1 overflow-auto pb-20 md:pb-0">
          <div className="p-4 md:p-8">
            <div className="flex flex-col md:flex-row md:items-center justify-between mb-6 md:mb-8 gap-4">
              <div>
                <h1 className="text-2xl md:text-3xl font-bold text-gray-800">Diskon</h1>
                <p className="text-gray-600 mt-1 text-sm md:text-base">Kelola promo dan diskon pelanggan</p>
              </div>
              <Dialog open={isDialogOpen} onOpenChange={(open) => {
                setIsDialogOpen(open)
                if (!open) resetForm()
              }}>
                <DialogTrigger>
                  <Button className="bg-gradient-to-r from-orange-500 to-red-500 hover:from-orange-600 hover:to-red-600">
                    <Plus className="w-4 h-4 mr-2" />
                    Tambah Diskon
                  </Button>
                </DialogTrigger>
                <DialogContent className="sm:max-w-md w-full md:w-auto">
                  <DialogHeader>
                    <DialogTitle>{editingDiscount ? 'Edit Diskon' : 'Tambah Diskon Baru'}</DialogTitle>
                  </DialogHeader>
                  <form onSubmit={handleSubmit} className="space-y-4">
                    <div>
                      <label className="text-sm font-medium text-gray-700">Nama Diskon</label>
                      <Input
                        value={formData.name}
                        onChange={(e) => setFormData({ ...formData, name: e.target.value })}
                        required
                      />
                    </div>
                    <div>
                      <label className="text-sm font-medium text-gray-700">Tipe Diskon</label>
                      <Select value={formData.type} onValueChange={(value: 'percentage' | 'fixed' | null) => setFormData({ ...formData, type: value as 'percentage' | 'fixed' })}>
                        <SelectTrigger>
                          <SelectValue />
                        </SelectTrigger>
                        <SelectContent>
                          <SelectItem value="percentage">Persentase (%)</SelectItem>
                          <SelectItem value="fixed">Nominal Tetap (Rp)</SelectItem>
                        </SelectContent>
                      </Select>
                    </div>
                    <div>
                      <label className="text-sm font-medium text-gray-700">
                        {formData.type === 'percentage' ? 'Persentase Diskon' : 'Nominal Diskon'}
                      </label>
                      <Input
                        type="number"
                        value={formData.value}
                        onChange={(e) => setFormData({ ...formData, value: e.target.value })}
                        required
                        min="0"
                        max={formData.type === 'percentage' ? '100' : undefined}
                      />
                    </div>
                    <div>
                      <label className="text-sm font-medium text-gray-700">Minimum Pembelian (Rp)</label>
                      <Input
                        type="number"
                        value={formData.min_purchase}
                        onChange={(e) => setFormData({ ...formData, min_purchase: e.target.value })}
                        min="0"
                      />
                    </div>
                    <div>
                      <label className="text-sm font-medium text-gray-700">Maksimum Diskon (Rp) - Opsional</label>
                      <Input
                        type="number"
                        value={formData.max_discount}
                        onChange={(e) => setFormData({ ...formData, max_discount: e.target.value })}
                        min="0"
                        placeholder="Kosongkan untuk tanpa batas"
                      />
                    </div>
                    <div>
                      <label className="text-sm font-medium text-gray-700">Berlaku Mulai</label>
                      <Input
                        type="date"
                        value={formData.valid_from}
                        onChange={(e) => setFormData({ ...formData, valid_from: e.target.value })}
                        required
                      />
                    </div>
                    <div>
                      <label className="text-sm font-medium text-gray-700">Berlaku Sampai - Opsional</label>
                      <Input
                        type="date"
                        value={formData.valid_until}
                        onChange={(e) => setFormData({ ...formData, valid_until: e.target.value })}
                        placeholder="Kosongkan untuk tanpa batas waktu"
                      />
                    </div>
                    <Button type="submit" className="w-full bg-gradient-to-r from-orange-500 to-red-500">
                      {editingDiscount ? 'Update' : 'Simpan'}
                    </Button>
                  </form>
                </DialogContent>
              </Dialog>
            </div>

            {/* Summary Card */}
            <Card className="shadow-lg mb-6">
              <CardHeader>
                <CardTitle className="text-sm font-medium text-gray-600 flex items-center gap-2">
                  <Percent className="w-4 h-4 text-orange-500" />
                  Total Diskon Aktif
                </CardTitle>
              </CardHeader>
              <CardContent>
                <div className="text-2xl font-bold text-gray-800">{discounts.filter(d => d.is_active).length} / {discounts.length}</div>
              </CardContent>
            </Card>

            <Card className="shadow-lg">
              <CardHeader>
                <div className="flex items-center gap-4">
                  <div className="relative flex-1">
                    <Search className="absolute left-3 top-1/2 transform -translate-y-1/2 text-gray-400 w-4 h-4" />
                    <Input
                      placeholder="Cari diskon..."
                      value={searchQuery}
                      onChange={(e) => setSearchQuery(e.target.value)}
                      className="pl-10"
                    />
                  </div>
                </div>
              </CardHeader>
              <CardContent>
                {/* Mobile Card Layout */}
                <div className="md:hidden space-y-3">
                  {filteredDiscounts.map((discount) => (
                    <div key={discount.id} className="p-4 bg-white rounded-lg border border-gray-200">
                      <div className="flex justify-between items-start mb-3">
                        <div className="flex-1">
                          <h4 className="font-semibold text-gray-800">{discount.name}</h4>
                          <div className="flex items-center gap-2 mt-1">
                            {discount.type === 'percentage' ? (
                              <span className="text-sm text-orange-600 font-medium">{discount.value}%</span>
                            ) : (
                              <span className="text-sm text-green-600 font-medium">Rp {discount.value.toLocaleString('id-ID')}</span>
                            )}
                            <span className="text-xs text-gray-500">Min: Rp {discount.min_purchase.toLocaleString('id-ID')}</span>
                          </div>
                        </div>
                        <Button
                          variant="ghost"
                          size="sm"
                          onClick={() => handleToggleActive(discount)}
                        >
                          {discount.is_active ? (
                            <ToggleRight className="w-5 h-5 text-green-500" />
                          ) : (
                            <ToggleLeft className="w-5 h-5 text-gray-400" />
                          )}
                        </Button>
                      </div>
                      <div className="flex gap-2 mt-4">
                        <Button
                          variant="outline"
                          size="sm"
                          className="flex-1"
                          onClick={() => handleEdit(discount)}
                        >
                          <Edit className="w-4 h-4 mr-1" />
                          Edit
                        </Button>
                        <Button
                          variant="outline"
                          size="sm"
                          className="flex-1"
                          onClick={() => handleDelete(discount.id)}
                        >
                          <Trash2 className="w-4 h-4 mr-1 text-red-500" />
                          Hapus
                        </Button>
                      </div>
                    </div>
                  ))}
                </div>
                {/* Desktop Table Layout */}
                <div className="hidden md:block overflow-x-auto">
                  <table className="w-full">
                    <thead>
                      <tr className="border-b border-gray-200">
                        <th className="text-left py-3 px-4 font-semibold text-gray-700">Nama</th>
                        <th className="text-left py-3 px-4 font-semibold text-gray-700">Tipe</th>
                        <th className="text-left py-3 px-4 font-semibold text-gray-700">Nilai</th>
                        <th className="text-left py-3 px-4 font-semibold text-gray-700">Min. Pembelian</th>
                        <th className="text-left py-3 px-4 font-semibold text-gray-700">Status</th>
                        <th className="text-left py-3 px-4 font-semibold text-gray-700">Aksi</th>
                      </tr>
                    </thead>
                    <tbody>
                      {filteredDiscounts.map((discount) => (
                        <tr key={discount.id} className="border-b border-gray-100 hover:bg-gray-50">
                          <td className="py-3 px-4 font-medium text-gray-800">{discount.name}</td>
                          <td className="py-3 px-4 text-gray-600">
                            {discount.type === 'percentage' ? (
                              <span className="flex items-center gap-1">
                                <Percent className="w-4 h-4" />
                                Persentase
                              </span>
                            ) : (
                              <span className="flex items-center gap-1">
                                <DollarSign className="w-4 h-4" />
                                Tetap
                              </span>
                            )}
                          </td>
                          <td className="py-3 px-4 text-gray-600">
                            {discount.type === 'percentage' 
                              ? `${discount.value}%` 
                              : `Rp ${discount.value.toLocaleString('id-ID')}`}
                          </td>
                          <td className="py-3 px-4 text-gray-600">
                            Rp {discount.min_purchase.toLocaleString('id-ID')}
                          </td>
                          <td className="py-3 px-4">
                            <Button
                              variant="ghost"
                              size="sm"
                              onClick={() => handleToggleActive(discount)}
                            >
                              {discount.is_active ? (
                                <ToggleRight className="w-5 h-5 text-green-500" />
                              ) : (
                                <ToggleLeft className="w-5 h-5 text-gray-400" />
                              )}
                            </Button>
                          </td>
                          <td className="py-3 px-4">
                            <div className="flex gap-2">
                              <Button
                                variant="ghost"
                                size="sm"
                                onClick={() => handleEdit(discount)}
                              >
                                <Edit className="w-4 h-4" />
                              </Button>
                              <Button
                                variant="ghost"
                                size="sm"
                                onClick={() => handleDelete(discount.id)}
                              >
                                <Trash2 className="w-4 h-4 text-red-500" />
                              </Button>
                            </div>
                          </td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
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
