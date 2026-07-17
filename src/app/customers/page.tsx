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
import { Plus, Edit, Trash2, Users, Search, Phone, Mail, MapPin, Wallet, Star } from 'lucide-react'

interface Customer {
  id: string
  name: string
  phone: string | null
  email: string | null
  address: string | null
  balance: number
  points: number
  notes: string | null
  is_active: boolean
  created_at: string
}

interface FormData {
  name: string
  phone: string
  email: string
  address: string
  balance: string
  points: string
  notes: string
}

export default function CustomersPage() {
  const { user, loading } = useAuth()
  const router = useRouter()
  const [customers, setCustomers] = useState<Customer[]>([])
  const [searchQuery, setSearchQuery] = useState('')
  const [isDialogOpen, setIsDialogOpen] = useState(false)
  const [editingCustomer, setEditingCustomer] = useState<Customer | null>(null)
  const [formData, setFormData] = useState<FormData>({
    name: '',
    phone: '',
    email: '',
    address: '',
    balance: '0',
    points: '0',
    notes: ''
  })

  useEffect(() => {
    if (!loading && !user) {
      router.push('/login')
    }
  }, [user, loading, router])

  useEffect(() => {
    if (user) {
      fetchCustomers()
    }
  }, [user])

  const fetchCustomers = async () => {
    try {
      const { data, error } = await supabase
        .from('customers')
        .select('*')
        .order('name')
      
      if (error) throw error
      setCustomers(data || [])
    } catch (error) {
      // Error will be handled by error boundary
      throw error
    }
  }

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    
    // Validate data
    const balance = parseFloat(formData.balance)
    const points = parseInt(formData.points)
    
    if (balance < 0) {
      alert('Saldo tidak boleh negatif')
      return
    }
    if (points < 0) {
      alert('Poin tidak boleh negatif')
      return
    }
    
    try {
      const customerData = {
        name: formData.name,
        phone: formData.phone || null,
        email: formData.email || null,
        address: formData.address || null,
        balance,
        points,
        notes: formData.notes || null
      }

      if (editingCustomer) {
        const { error } = await supabase
          .from('customers')
          .update(customerData)
          .eq('id', editingCustomer.id)
        
        if (error) throw error
      } else {
        const { error } = await supabase
          .from('customers')
          .insert(customerData)
        
        if (error) throw error
      }

      setIsDialogOpen(false)
      resetForm()
      fetchCustomers()
    } catch (error) {
      alert('Terjadi kesalahan saat menyimpan pelanggan')
    }
  }

  const handleEdit = (customer: Customer) => {
    setEditingCustomer(customer)
    setFormData({
      name: customer.name,
      phone: customer.phone || '',
      email: customer.email || '',
      address: customer.address || '',
      balance: customer.balance.toString(),
      points: customer.points.toString(),
      notes: customer.notes || ''
    })
    setIsDialogOpen(true)
  }

  const handleDelete = async (id: string) => {
    if (!confirm('Apakah Anda yakin ingin menghapus pelanggan ini?')) return
    
    try {
      // Soft delete: set is_active to false
      const { error } = await supabase
        .from('customers')
        .update({ is_active: false })
        .eq('id', id)
      
      if (error) throw error
      fetchCustomers()
    } catch (error) {
      alert('Terjadi kesalahan saat menghapus pelanggan')
    }
  }

  const resetForm = () => {
    setFormData({
      name: '',
      phone: '',
      email: '',
      address: '',
      balance: '0',
      points: '0',
      notes: ''
    })
    setEditingCustomer(null)
  }

  const filteredCustomers = customers.filter(customer => {
    const matchesSearch = customer.name.toLowerCase().includes(searchQuery.toLowerCase()) ||
                         (customer.phone && customer.phone.includes(searchQuery)) ||
                         (customer.email && customer.email.toLowerCase().includes(searchQuery.toLowerCase()))
    return matchesSearch
  })

  if (loading || !user) {
    return null
  }

  return (
    <ProtectedRoute allowedRoles={['admin', 'kasir']}>
      <div className="flex h-screen bg-gray-50">
        <Sidebar />
        <main className="flex-1 overflow-auto pb-20 md:pb-0">
          <div className="p-4 md:p-8">
            <div className="flex flex-col md:flex-row md:items-center justify-between mb-6 md:mb-8 gap-4">
              <div>
                <h1 className="text-2xl md:text-3xl font-bold text-gray-800">Pelanggan</h1>
                <p className="text-gray-600 mt-1 text-sm md:text-base">Kelola data pelanggan dan riwayat transaksi</p>
              </div>
              <Dialog open={isDialogOpen} onOpenChange={(open) => {
                setIsDialogOpen(open)
                if (!open) resetForm()
              }}>
                <DialogTrigger>
                  <Button className="bg-gradient-to-r from-orange-500 to-red-500 hover:from-orange-600 hover:to-red-600">
                    <Plus className="w-4 h-4 mr-2" />
                    Tambah Pelanggan
                  </Button>
                </DialogTrigger>
                <DialogContent className="sm:max-w-md w-full md:w-auto">
                  <DialogHeader>
                    <DialogTitle>{editingCustomer ? 'Edit Pelanggan' : 'Tambah Pelanggan Baru'}</DialogTitle>
                  </DialogHeader>
                  <form onSubmit={handleSubmit} className="space-y-4">
                    <div>
                      <label className="text-sm font-medium text-gray-700">Nama Pelanggan</label>
                      <Input
                        value={formData.name}
                        onChange={(e) => setFormData({ ...formData, name: e.target.value })}
                        required
                      />
                    </div>
                    <div>
                      <label className="text-sm font-medium text-gray-700">No. Telepon</label>
                      <Input
                        value={formData.phone}
                        onChange={(e) => setFormData({ ...formData, phone: e.target.value })}
                        placeholder="08xxxxxxxxxx"
                      />
                    </div>
                    <div>
                      <label className="text-sm font-medium text-gray-700">Email</label>
                      <Input
                        type="email"
                        value={formData.email}
                        onChange={(e) => setFormData({ ...formData, email: e.target.value })}
                        placeholder="email@contoh.com"
                      />
                    </div>
                    <div>
                      <label className="text-sm font-medium text-gray-700">Alamat</label>
                      <Input
                        value={formData.address}
                        onChange={(e) => setFormData({ ...formData, address: e.target.value })}
                        placeholder="Alamat lengkap"
                      />
                    </div>
                    <div>
                      <label className="text-sm font-medium text-gray-700">Saldo (Rp)</label>
                      <Input
                        type="number"
                        value={formData.balance}
                        onChange={(e) => setFormData({ ...formData, balance: e.target.value })}
                        min="0"
                      />
                    </div>
                    <div>
                      <label className="text-sm font-medium text-gray-700">Poin</label>
                      <Input
                        type="number"
                        value={formData.points}
                        onChange={(e) => setFormData({ ...formData, points: e.target.value })}
                        min="0"
                      />
                    </div>
                    <div>
                      <label className="text-sm font-medium text-gray-700">Catatan</label>
                      <Input
                        value={formData.notes}
                        onChange={(e) => setFormData({ ...formData, notes: e.target.value })}
                        placeholder="Catatan tambahan"
                      />
                    </div>
                    <Button type="submit" className="w-full bg-gradient-to-r from-orange-500 to-red-500">
                      {editingCustomer ? 'Update' : 'Simpan'}
                    </Button>
                  </form>
                </DialogContent>
              </Dialog>
            </div>

            {/* Summary Cards */}
            <div className="grid grid-cols-1 md:grid-cols-3 gap-4 mb-6">
              <Card className="shadow-lg">
                <CardHeader>
                  <CardTitle className="text-sm font-medium text-gray-600 flex items-center gap-2">
                    <Users className="w-4 h-4 text-orange-500" />
                    Total Pelanggan
                  </CardTitle>
                </CardHeader>
                <CardContent>
                  <div className="text-2xl font-bold text-gray-800">{customers.length}</div>
                </CardContent>
              </Card>
              <Card className="shadow-lg">
                <CardHeader>
                  <CardTitle className="text-sm font-medium text-gray-600 flex items-center gap-2">
                    <Wallet className="w-4 h-4 text-green-500" />
                    Total Saldo Pelanggan
                  </CardTitle>
                </CardHeader>
                <CardContent>
                  <div className="text-2xl font-bold text-green-600">
                    Rp {customers.reduce((sum, c) => sum + c.balance, 0).toLocaleString('id-ID')}
                  </div>
                </CardContent>
              </Card>
              <Card className="shadow-lg">
                <CardHeader>
                  <CardTitle className="text-sm font-medium text-gray-600 flex items-center gap-2">
                    <Star className="w-4 h-4 text-yellow-500" />
                    Total Poin Pelanggan
                  </CardTitle>
                </CardHeader>
                <CardContent>
                  <div className="text-2xl font-bold text-yellow-600">
                    {customers.reduce((sum, c) => sum + c.points, 0)}
                  </div>
                </CardContent>
              </Card>
            </div>

            <Card className="shadow-lg">
              <CardHeader>
                <div className="flex items-center gap-4">
                  <div className="relative flex-1">
                    <Search className="absolute left-3 top-1/2 transform -translate-y-1/2 text-gray-400 w-4 h-4" />
                    <Input
                      placeholder="Cari pelanggan..."
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
                  {filteredCustomers.map((customer) => (
                    <div key={customer.id} className="p-4 bg-white rounded-lg border border-gray-200">
                      <div className="flex justify-between items-start mb-3">
                        <div className="flex-1">
                          <h4 className="font-semibold text-gray-800">{customer.name}</h4>
                          {customer.phone && (
                            <p className="text-sm text-gray-500 flex items-center gap-1">
                              <Phone className="w-3 h-3" />
                              {customer.phone}
                            </p>
                          )}
                        </div>
                      </div>
                      <div className="space-y-2 text-sm">
                        <div className="flex justify-between">
                          <span className="text-gray-500">Saldo</span>
                          <span className="font-medium">Rp {customer.balance.toLocaleString('id-ID')}</span>
                        </div>
                        <div className="flex justify-between">
                          <span className="text-gray-500">Poin</span>
                          <span className="font-medium">{customer.points}</span>
                        </div>
                      </div>
                      <div className="flex gap-2 mt-4">
                        <Button
                          variant="outline"
                          size="sm"
                          className="flex-1"
                          onClick={() => handleEdit(customer)}
                        >
                          <Edit className="w-4 h-4 mr-1" />
                          Edit
                        </Button>
                        <Button
                          variant="outline"
                          size="sm"
                          className="flex-1"
                          onClick={() => handleDelete(customer.id)}
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
                        <th className="text-left py-3 px-4 font-semibold text-gray-700">Telepon</th>
                        <th className="text-left py-3 px-4 font-semibold text-gray-700">Email</th>
                        <th className="text-left py-3 px-4 font-semibold text-gray-700">Saldo</th>
                        <th className="text-left py-3 px-4 font-semibold text-gray-700">Poin</th>
                        <th className="text-left py-3 px-4 font-semibold text-gray-700">Aksi</th>
                      </tr>
                    </thead>
                    <tbody>
                      {filteredCustomers.map((customer) => (
                        <tr key={customer.id} className="border-b border-gray-100 hover:bg-gray-50">
                          <td className="py-3 px-4 font-medium text-gray-800">{customer.name}</td>
                          <td className="py-3 px-4 text-gray-600">{customer.phone || '-'}</td>
                          <td className="py-3 px-4 text-gray-600">{customer.email || '-'}</td>
                          <td className="py-3 px-4 text-gray-600">
                            Rp {customer.balance.toLocaleString('id-ID')}
                          </td>
                          <td className="py-3 px-4 text-gray-600">{customer.points}</td>
                          <td className="py-3 px-4">
                            <div className="flex gap-2">
                              <Button
                                variant="ghost"
                                size="sm"
                                onClick={() => handleEdit(customer)}
                              >
                                <Edit className="w-4 h-4" />
                              </Button>
                              <Button
                                variant="ghost"
                                size="sm"
                                onClick={() => handleDelete(customer.id)}
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
