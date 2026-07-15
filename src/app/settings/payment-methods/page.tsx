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
import { supabase } from '@/lib/supabase'
import { Plus, Edit, Trash2, CreditCard, Search } from 'lucide-react'

interface PaymentMethod {
  id: string
  name: string
  code: string
  is_active: boolean
  sort_order: number
}

export default function PaymentMethodsPage() {
  const { user, loading } = useAuth()
  const router = useRouter()
  const [paymentMethods, setPaymentMethods] = useState<PaymentMethod[]>([])
  const [searchQuery, setSearchQuery] = useState('')
  const [isDialogOpen, setIsDialogOpen] = useState(false)
  const [editingMethod, setEditingMethod] = useState<PaymentMethod | null>(null)
  const [formData, setFormData] = useState({
    name: '',
    code: '',
    sort_order: '0'
  })

  useEffect(() => {
    if (!loading && !user) {
      router.push('/login')
    }
  }, [user, loading, router])

  useEffect(() => {
    if (user) {
      fetchPaymentMethods()
    }
  }, [user])

  const fetchPaymentMethods = async () => {
    try {
      const { data, error } = await supabase
        .from('payment_methods')
        .select('*')
        .order('sort_order')
      
      if (error) throw error
      setPaymentMethods(data || [])
    } catch (error) {
      console.error('Error fetching payment methods:', error)
    }
  }

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    try {
      const methodData = {
        name: formData.name,
        code: formData.code.toLowerCase().replace(/\s+/g, '_'),
        sort_order: parseInt(formData.sort_order)
      }

      if (editingMethod) {
        const { error } = await supabase
          .from('payment_methods')
          .update(methodData)
          .eq('id', editingMethod.id)
        
        if (error) throw error
      } else {
        const { error } = await supabase
          .from('payment_methods')
          .insert(methodData)
        
        if (error) throw error
      }

      setIsDialogOpen(false)
      resetForm()
      fetchPaymentMethods()
    } catch (error) {
      console.error('Error saving payment method:', error)
      alert('Terjadi kesalahan saat menyimpan metode pembayaran')
    }
  }

  const handleEdit = (method: PaymentMethod) => {
    setEditingMethod(method)
    setFormData({
      name: method.name,
      code: method.code,
      sort_order: method.sort_order.toString()
    })
    setIsDialogOpen(true)
  }

  const handleDelete = async (id: string) => {
    if (!confirm('Apakah Anda yakin ingin menghapus metode pembayaran ini?')) return
    
    try {
      const { error } = await supabase
        .from('payment_methods')
        .delete()
        .eq('id', id)
      
      if (error) throw error
      fetchPaymentMethods()
    } catch (error) {
      console.error('Error deleting payment method:', error)
      alert('Terjadi kesalahan saat menghapus metode pembayaran')
    }
  }

  const resetForm = () => {
    setFormData({
      name: '',
      code: '',
      sort_order: '0'
    })
    setEditingMethod(null)
  }

  const filteredMethods = paymentMethods.filter(method => {
    return method.name.toLowerCase().includes(searchQuery.toLowerCase()) ||
           method.code.toLowerCase().includes(searchQuery.toLowerCase())
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
                <h1 className="text-2xl md:text-3xl font-bold text-gray-800">Metode Pembayaran</h1>
                <p className="text-gray-600 mt-1 text-sm md:text-base">Kelola metode pembayaran untuk transaksi</p>
              </div>
              <Dialog open={isDialogOpen} onOpenChange={(open) => {
                setIsDialogOpen(open)
                if (!open) resetForm()
              }}>
                <DialogTrigger>
                  <Button className="bg-gradient-to-r from-orange-500 to-red-500 hover:from-orange-600 hover:to-red-600">
                    <Plus className="w-4 h-4 mr-2" />
                    Tambah Metode Pembayaran
                  </Button>
                </DialogTrigger>
                <DialogContent className="sm:max-w-md w-full md:w-auto">
                  <DialogHeader>
                    <DialogTitle>{editingMethod ? 'Edit Metode Pembayaran' : 'Tambah Metode Pembayaran Baru'}</DialogTitle>
                  </DialogHeader>
                  <form onSubmit={handleSubmit} className="space-y-4">
                    <div>
                      <label className="text-sm font-medium text-gray-700">Nama Metode</label>
                      <Input
                        value={formData.name}
                        onChange={(e) => setFormData({ ...formData, name: e.target.value })}
                        placeholder="Contoh: Tunai, Transfer, QRIS, E-Wallet"
                        required
                      />
                    </div>
                    <div>
                      <label className="text-sm font-medium text-gray-700">Kode (Unik)</label>
                      <Input
                        value={formData.code}
                        onChange={(e) => setFormData({ ...formData, code: e.target.value.toLowerCase().replace(/\s+/g, '_') })}
                        placeholder="Contoh: cash, transfer, qris, ewallet"
                        required
                      />
                      <p className="text-xs text-gray-500 mt-1">Kode akan otomatis diubah ke lowercase dan underscore</p>
                    </div>
                    <div>
                      <label className="text-sm font-medium text-gray-700">Urutan</label>
                      <Input
                        type="number"
                        value={formData.sort_order}
                        onChange={(e) => setFormData({ ...formData, sort_order: e.target.value })}
                        required
                      />
                    </div>
                    <Button type="submit" className="w-full bg-gradient-to-r from-orange-500 to-red-500">
                      {editingMethod ? 'Update' : 'Simpan'}
                    </Button>
                  </form>
                </DialogContent>
              </Dialog>
            </div>

            <Card className="shadow-lg">
              <CardHeader>
                <div className="flex items-center gap-4">
                  <div className="relative flex-1">
                    <Search className="absolute left-3 top-1/2 transform -translate-y-1/2 text-gray-400 w-4 h-4" />
                    <Input
                      placeholder="Cari metode pembayaran..."
                      value={searchQuery}
                      onChange={(e) => setSearchQuery(e.target.value)}
                      className="pl-10"
                    />
                  </div>
                </div>
              </CardHeader>
              <CardContent>
                <div className="space-y-3">
                  {filteredMethods.map((method) => (
                    <div key={method.id} className="p-4 bg-white rounded-lg border border-gray-200 flex items-center justify-between">
                      <div className="flex items-center gap-4">
                        <div className="w-12 h-12 rounded-lg bg-gradient-to-br from-blue-500 to-indigo-500 flex items-center justify-center">
                          <CreditCard className="w-6 h-6 text-white" />
                        </div>
                        <div>
                          <h4 className="font-semibold text-gray-800">{method.name}</h4>
                          <p className="text-sm text-gray-500">Kode: {method.code} | Urutan: {method.sort_order}</p>
                        </div>
                      </div>
                      <div className="flex gap-2">
                        <Button
                          variant="outline"
                          size="sm"
                          onClick={() => handleEdit(method)}
                        >
                          <Edit className="w-4 h-4" />
                        </Button>
                        <Button
                          variant="outline"
                          size="sm"
                          onClick={() => handleDelete(method.id)}
                        >
                          <Trash2 className="w-4 h-4 text-red-500" />
                        </Button>
                      </div>
                    </div>
                  ))}
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
