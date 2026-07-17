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
import { Plus, Edit, Trash2, Truck, Search, Phone, MapPin } from 'lucide-react'

interface Supplier {
  id: string
  name: string
  contact: string | null
  address: string | null
  created_at: string
}

interface FormData {
  name: string
  contact: string
  address: string
}

export default function SuppliersPage() {
  const { user, loading } = useAuth()
  const router = useRouter()
  const [suppliers, setSuppliers] = useState<Supplier[]>([])
  const [searchQuery, setSearchQuery] = useState('')
  const [isDialogOpen, setIsDialogOpen] = useState(false)
  const [editingSupplier, setEditingSupplier] = useState<Supplier | null>(null)
  const [formData, setFormData] = useState<FormData>({
    name: '',
    contact: '',
    address: ''
  })

  useEffect(() => {
    if (!loading && !user) {
      router.push('/login')
    }
  }, [user, loading, router])

  useEffect(() => {
    if (user) {
      fetchSuppliers()
    }
  }, [user])

  const fetchSuppliers = async () => {
    try {
      const { data, error } = await supabase
        .from('suppliers')
        .select('*')
        .order('name')
      
      if (error) throw error
      setSuppliers(data || [])
    } catch (error) {
      // Error will be handled by error boundary
      throw error
    }
  }

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    
    try {
      const supplierData = {
        name: formData.name,
        contact: formData.contact || null,
        address: formData.address || null
      }

      if (editingSupplier) {
        const { error } = await supabase
          .from('suppliers')
          .update(supplierData)
          .eq('id', editingSupplier.id)
        
        if (error) throw error
      } else {
        const { error } = await supabase
          .from('suppliers')
          .insert(supplierData)
        
        if (error) throw error
      }

      setIsDialogOpen(false)
      resetForm()
      fetchSuppliers()
    } catch (error) {
      alert('Terjadi kesalahan saat menyimpan supplier')
    }
  }

  const handleEdit = (supplier: Supplier) => {
    setEditingSupplier(supplier)
    setFormData({
      name: supplier.name,
      contact: supplier.contact || '',
      address: supplier.address || ''
    })
    setIsDialogOpen(true)
  }

  const handleDelete = async (id: string) => {
    if (!confirm('Apakah Anda yakin ingin menghapus supplier ini?')) return
    
    try {
      // Soft delete: set is_active to false
      const { error } = await supabase
        .from('suppliers')
        .update({ is_active: false })
        .eq('id', id)
      
      if (error) throw error
      fetchSuppliers()
    } catch (error) {
      alert('Terjadi kesalahan saat menghapus supplier')
    }
  }

  const resetForm = () => {
    setFormData({
      name: '',
      contact: '',
      address: ''
    })
    setEditingSupplier(null)
  }

  const filteredSuppliers = suppliers.filter(supplier => {
    const matchesSearch = supplier.name.toLowerCase().includes(searchQuery.toLowerCase()) ||
                         (supplier.contact && supplier.contact.includes(searchQuery))
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
                <h1 className="text-2xl md:text-3xl font-bold text-gray-800">Supplier</h1>
                <p className="text-gray-600 mt-1 text-sm md:text-base">Kelola data supplier bahan baku</p>
              </div>
              <Dialog open={isDialogOpen} onOpenChange={(open) => {
                setIsDialogOpen(open)
                if (!open) resetForm()
              }}>
                <DialogTrigger>
                  <Button className="bg-gradient-to-r from-orange-500 to-red-500 hover:from-orange-600 hover:to-red-600">
                    <Plus className="w-4 h-4 mr-2" />
                    Tambah Supplier
                  </Button>
                </DialogTrigger>
                <DialogContent className="sm:max-w-md w-full md:w-auto">
                  <DialogHeader>
                    <DialogTitle>{editingSupplier ? 'Edit Supplier' : 'Tambah Supplier Baru'}</DialogTitle>
                  </DialogHeader>
                  <form onSubmit={handleSubmit} className="space-y-4">
                    <div>
                      <label className="text-sm font-medium text-gray-700">Nama Supplier</label>
                      <Input
                        value={formData.name}
                        onChange={(e) => setFormData({ ...formData, name: e.target.value })}
                        required
                      />
                    </div>
                    <div>
                      <label className="text-sm font-medium text-gray-700">Kontak</label>
                      <Input
                        value={formData.contact}
                        onChange={(e) => setFormData({ ...formData, contact: e.target.value })}
                        placeholder="No. telepon atau email"
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
                    <Button type="submit" className="w-full bg-gradient-to-r from-orange-500 to-red-500">
                      {editingSupplier ? 'Update' : 'Simpan'}
                    </Button>
                  </form>
                </DialogContent>
              </Dialog>
            </div>

            {/* Summary Card */}
            <Card className="shadow-lg mb-6">
              <CardHeader>
                <CardTitle className="text-sm font-medium text-gray-600 flex items-center gap-2">
                  <Truck className="w-4 h-4 text-orange-500" />
                  Total Supplier
                </CardTitle>
              </CardHeader>
              <CardContent>
                <div className="text-2xl font-bold text-gray-800">{suppliers.length}</div>
              </CardContent>
            </Card>

            <Card className="shadow-lg">
              <CardHeader>
                <div className="flex items-center gap-4">
                  <div className="relative flex-1">
                    <Search className="absolute left-3 top-1/2 transform -translate-y-1/2 text-gray-400 w-4 h-4" />
                    <Input
                      placeholder="Cari supplier..."
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
                  {filteredSuppliers.map((supplier) => (
                    <div key={supplier.id} className="p-4 bg-white rounded-lg border border-gray-200">
                      <div className="flex justify-between items-start mb-3">
                        <div className="flex-1">
                          <h4 className="font-semibold text-gray-800">{supplier.name}</h4>
                          {supplier.contact && (
                            <p className="text-sm text-gray-500 flex items-center gap-1">
                              <Phone className="w-3 h-3" />
                              {supplier.contact}
                            </p>
                          )}
                          {supplier.address && (
                            <p className="text-sm text-gray-500 flex items-center gap-1 mt-1">
                              <MapPin className="w-3 h-3" />
                              {supplier.address}
                            </p>
                          )}
                        </div>
                      </div>
                      <div className="flex gap-2 mt-4">
                        <Button
                          variant="outline"
                          size="sm"
                          className="flex-1"
                          onClick={() => handleEdit(supplier)}
                        >
                          <Edit className="w-4 h-4 mr-1" />
                          Edit
                        </Button>
                        <Button
                          variant="outline"
                          size="sm"
                          className="flex-1"
                          onClick={() => handleDelete(supplier.id)}
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
                        <th className="text-left py-3 px-4 font-semibold text-gray-700">Kontak</th>
                        <th className="text-left py-3 px-4 font-semibold text-gray-700">Alamat</th>
                        <th className="text-left py-3 px-4 font-semibold text-gray-700">Aksi</th>
                      </tr>
                    </thead>
                    <tbody>
                      {filteredSuppliers.map((supplier) => (
                        <tr key={supplier.id} className="border-b border-gray-100 hover:bg-gray-50">
                          <td className="py-3 px-4 font-medium text-gray-800">{supplier.name}</td>
                          <td className="py-3 px-4 text-gray-600">{supplier.contact || '-'}</td>
                          <td className="py-3 px-4 text-gray-600">{supplier.address || '-'}</td>
                          <td className="py-3 px-4">
                            <div className="flex gap-2">
                              <Button
                                variant="ghost"
                                size="sm"
                                onClick={() => handleEdit(supplier)}
                              >
                                <Edit className="w-4 h-4" />
                              </Button>
                              <Button
                                variant="ghost"
                                size="sm"
                                onClick={() => handleDelete(supplier.id)}
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
