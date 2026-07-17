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
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select'
import { Dialog, DialogContent, DialogHeader, DialogTitle, DialogTrigger } from '@/components/ui/dialog'
import { supabase } from '@/lib/supabase'
import { Plus, Edit, Trash2, Package, Search } from 'lucide-react'

interface Category {
  id: string
  name: string
  icon: string | null
  color: string | null
  is_active: boolean
  sort_order: number
}

const iconOptions = [
  { value: 'Package', label: 'Package (Default)' },
  { value: 'Cake', label: 'Cake (Bakery)' },
  { value: 'Coffee', label: 'Coffee (Beverages)' },
  { value: 'Cookie', label: 'Cookie (Snacks)' },
  { value: 'Wheat', label: 'Wheat (Ingredients)' },
  { value: 'ShoppingBag', label: 'Shopping Bag' },
  { value: 'Store', label: 'Store' },
]

const colorOptions = [
  { value: 'from-gray-500 to-gray-600', label: 'Gray' },
  { value: 'from-orange-500 to-red-500', label: 'Orange-Red' },
  { value: 'from-yellow-500 to-orange-500', label: 'Yellow-Orange' },
  { value: 'from-blue-500 to-indigo-500', label: 'Blue-Indigo' },
  { value: 'from-green-500 to-emerald-500', label: 'Green-Emerald' },
  { value: 'from-purple-500 to-violet-500', label: 'Purple-Violet' },
  { value: 'from-pink-500 to-rose-500', label: 'Pink-Rose' },
  { value: 'from-teal-500 to-cyan-500', label: 'Teal-Cyan' },
]

export default function CategoriesPage() {
  const { user, loading } = useAuth()
  const router = useRouter()
  const [categories, setCategories] = useState<Category[]>([])
  const [searchQuery, setSearchQuery] = useState('')
  const [isDialogOpen, setIsDialogOpen] = useState(false)
  const [editingCategory, setEditingCategory] = useState<Category | null>(null)
  const [formData, setFormData] = useState<{
    name: string
    icon: string
    color: string
    sort_order: string
  }>({
    name: '',
    icon: 'Package',
    color: 'from-gray-500 to-gray-600',
    sort_order: '0'
  })

  useEffect(() => {
    if (!loading && !user) {
      router.push('/login')
    }
  }, [user, loading, router])

  useEffect(() => {
    if (user) {
      fetchCategories()
    }
  }, [user])

  const fetchCategories = async () => {
    try {
      const { data, error } = await supabase
        .from('categories')
        .select('*')
        .order('sort_order')
      
      if (error) throw error
      setCategories(data || [])
    } catch (error) {
      // Error will be handled by error boundary
      throw error
    }
  }

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    try {
      const categoryData = {
        name: formData.name,
        icon: formData.icon,
        color: formData.color,
        sort_order: parseInt(formData.sort_order)
      }

      if (editingCategory) {
        const { error } = await supabase
          .from('categories')
          .update(categoryData)
          .eq('id', editingCategory.id)
        
        if (error) throw error
      } else {
        const { error } = await supabase
          .from('categories')
          .insert(categoryData)
        
        if (error) throw error
      }

      setIsDialogOpen(false)
      resetForm()
      fetchCategories()
    } catch (error) {
      alert('Terjadi kesalahan saat menyimpan kategori')
    }
  }

  const handleEdit = (category: Category) => {
    setEditingCategory(category)
    setFormData({
      name: category.name,
      icon: category.icon ?? 'Package',
      color: category.color ?? 'from-gray-500 to-gray-600',
      sort_order: category.sort_order.toString()
    })
    setIsDialogOpen(true)
  }

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

  const resetForm = () => {
    setFormData({
      name: '',
      icon: 'Package',
      color: 'from-gray-500 to-gray-600',
      sort_order: '0'
    })
    setEditingCategory(null)
  }

  const filteredCategories = categories.filter(category => {
    return category.name.toLowerCase().includes(searchQuery.toLowerCase())
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
                <h1 className="text-2xl md:text-3xl font-bold text-gray-800">Kategori Produk</h1>
                <p className="text-gray-600 mt-1 text-sm md:text-base">Kelola kategori produk untuk toko</p>
              </div>
              <Dialog open={isDialogOpen} onOpenChange={(open) => {
                setIsDialogOpen(open)
                if (!open) resetForm()
              }}>
                <DialogTrigger>
                  <Button className="bg-gradient-to-r from-orange-500 to-red-500 hover:from-orange-600 hover:to-red-600">
                    <Plus className="w-4 h-4 mr-2" />
                    Tambah Kategori
                  </Button>
                </DialogTrigger>
                <DialogContent className="sm:max-w-md w-full md:w-auto">
                  <DialogHeader>
                    <DialogTitle>{editingCategory ? 'Edit Kategori' : 'Tambah Kategori Baru'}</DialogTitle>
                  </DialogHeader>
                  <form onSubmit={handleSubmit} className="space-y-4">
                    <div>
                      <label className="text-sm font-medium text-gray-700">Nama Kategori</label>
                      <Input
                        value={formData.name}
                        onChange={(e) => setFormData({ ...formData, name: e.target.value })}
                        required
                      />
                    </div>
                    <div>
                      <label className="text-sm font-medium text-gray-700">Icon</label>
                      <Select value={formData.icon} onValueChange={(value: string | null) => setFormData({ ...formData, icon: value || 'Package' })}>
                        <SelectTrigger>
                          <SelectValue />
                        </SelectTrigger>
                        <SelectContent>
                          {iconOptions.map((option) => (
                            <SelectItem key={option.value} value={option.value}>
                              {option.label}
                            </SelectItem>
                          ))}
                        </SelectContent>
                      </Select>
                    </div>
                    <div>
                      <label className="text-sm font-medium text-gray-700">Warna</label>
                      <Select value={formData.color} onValueChange={(value: string | null) => setFormData({ ...formData, color: value || 'from-gray-500 to-gray-600' })}>
                        <SelectTrigger>
                          <SelectValue />
                        </SelectTrigger>
                        <SelectContent>
                          {colorOptions.map((option) => (
                            <SelectItem key={option.value} value={option.value}>
                              {option.label}
                            </SelectItem>
                          ))}
                        </SelectContent>
                      </Select>
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
                      {editingCategory ? 'Update' : 'Simpan'}
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
                      placeholder="Cari kategori..."
                      value={searchQuery}
                      onChange={(e) => setSearchQuery(e.target.value)}
                      className="pl-10"
                    />
                  </div>
                </div>
              </CardHeader>
              <CardContent>
                <div className="space-y-3">
                  {filteredCategories.map((category) => (
                    <div key={category.id} className="p-4 bg-white rounded-lg border border-gray-200 flex items-center justify-between">
                      <div className="flex items-center gap-4">
                        <div className={`w-12 h-12 rounded-lg bg-gradient-to-br ${category.color || 'from-gray-500 to-gray-600'} flex items-center justify-center`}>
                          <Package className="w-6 h-6 text-white" />
                        </div>
                        <div>
                          <h4 className="font-semibold text-gray-800">{category.name}</h4>
                          <p className="text-sm text-gray-500">Icon: {category.icon || 'Package'} | Urutan: {category.sort_order}</p>
                        </div>
                      </div>
                      <div className="flex gap-2">
                        <Button
                          variant="outline"
                          size="sm"
                          onClick={() => handleEdit(category)}
                        >
                          <Edit className="w-4 h-4" />
                        </Button>
                        <Button
                          variant="outline"
                          size="sm"
                          onClick={() => handleDelete(category.id)}
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
