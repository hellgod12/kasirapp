'use client'

import { useEffect, useState } from 'react'
import { useAuth } from '@/contexts/AuthContext'
import { useRouter } from 'next/navigation'
import { Sidebar } from '@/components/Sidebar'
import { ProtectedRoute } from '@/components/ProtectedRoute'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select'
import { Dialog, DialogContent, DialogHeader, DialogTitle, DialogTrigger } from '@/components/ui/dialog'
import { supabase } from '@/lib/supabase'
import { Plus, Edit, Trash2, BookOpen, Search } from 'lucide-react'

interface ProductRecipe {
  id: string
  product_id: string
  raw_material_id: string
  quantity_used: number
  created_at: string
  products?: { name: string }
  raw_materials?: { name: string, unit: string, cost_per_unit: number }
}

interface Product {
  id: string
  name: string
}

interface RawMaterial {
  id: string
  name: string
  unit: string
  cost_per_unit: number
}

export default function RecipesPage() {
  const { user, loading } = useAuth()
  const router = useRouter()
  const [recipes, setRecipes] = useState<ProductRecipe[]>([])
  const [products, setProducts] = useState<Product[]>([])
  const [rawMaterials, setRawMaterials] = useState<RawMaterial[]>([])
  const [searchQuery, setSearchQuery] = useState('')
  const [isDialogOpen, setIsDialogOpen] = useState(false)
  const [editingRecipe, setEditingRecipe] = useState<ProductRecipe | null>(null)
  const [formData, setFormData] = useState({
    product_id: '',
    raw_material_id: '',
    quantity_used: ''
  })

  useEffect(() => {
    if (!loading && !user) {
      router.push('/login')
    }
  }, [user, loading, router])

  useEffect(() => {
    if (user) {
      fetchRecipes()
      fetchProducts()
      fetchRawMaterials()
    }
  }, [user])

  const fetchRecipes = async () => {
    try {
      const { data, error } = await supabase
        .from('product_recipes')
        .select('*, products!inner(name), raw_materials!inner(name, unit, cost_per_unit)')
        .order('created_at', { ascending: false })
      
      if (error) throw error
      setRecipes(data || [])
    } catch (error) {
      console.error('Error fetching recipes:', error)
    }
  }

  const fetchProducts = async () => {
    try {
      const { data, error } = await supabase
        .from('products')
        .select('id, name')
        .eq('is_active', true)
        .order('name')
      
      if (error) throw error
      setProducts(data || [])
    } catch (error) {
      console.error('Error fetching products:', error)
    }
  }

  const fetchRawMaterials = async () => {
    try {
      const { data, error } = await supabase
        .from('raw_materials')
        .select('id, name, unit, cost_per_unit')
        .order('name')
      
      if (error) throw error
      setRawMaterials(data || [])
    } catch (error) {
      console.error('Error fetching raw materials:', error)
    }
  }

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    try {
      const recipeData = {
        product_id: formData.product_id,
        raw_material_id: formData.raw_material_id,
        quantity_used: parseFloat(formData.quantity_used)
      }

      if (editingRecipe) {
        const { error } = await supabase
          .from('product_recipes')
          .update(recipeData)
          .eq('id', editingRecipe.id)
        
        if (error) throw error
      } else {
        const { error } = await supabase
          .from('product_recipes')
          .insert(recipeData)
        
        if (error) throw error
      }

      // Update product HPP
      await updateProductHPP(formData.product_id)

      setIsDialogOpen(false)
      resetForm()
      fetchRecipes()
    } catch (error) {
      console.error('Error saving recipe:', error)
      alert('Terjadi kesalahan saat menyimpan resep')
    }
  }

  const updateProductHPP = async (productId: string) => {
    try {
      // Call the database function to calculate HPP
      const { error } = await supabase.rpc('calculate_product_hpp', { product_uuid: productId })
      if (error) throw error

      // Update the product's HPP
      const { error: updateError } = await supabase
        .from('products')
        .update({ hpp: (await supabase.rpc('calculate_product_hpp', { product_uuid: productId })) })
        .eq('id', productId)

      if (updateError) throw updateError
    } catch (error) {
      console.error('Error updating product HPP:', error)
    }
  }

  const handleEdit = (recipe: ProductRecipe) => {
    setEditingRecipe(recipe)
    setFormData({
      product_id: recipe.product_id,
      raw_material_id: recipe.raw_material_id,
      quantity_used: recipe.quantity_used.toString()
    })
    setIsDialogOpen(true)
  }

  const handleDelete = async (id: string, productId: string) => {
    if (!confirm('Apakah Anda yakin ingin menghapus resep ini?')) return
    
    try {
      const { error } = await supabase
        .from('product_recipes')
        .delete()
        .eq('id', id)
      
      if (error) throw error
      
      // Update product HPP after deletion
      await updateProductHPP(productId)
      
      fetchRecipes()
    } catch (error) {
      console.error('Error deleting recipe:', error)
      alert('Terjadi kesalahan saat menghapus resep')
    }
  }

  const resetForm = () => {
    setFormData({
      product_id: '',
      raw_material_id: '',
      quantity_used: ''
    })
    setEditingRecipe(null)
  }

  const filteredRecipes = recipes.filter(recipe => {
    const productName = (recipe as any).products?.name || ''
    const materialName = (recipe as any).raw_materials?.name || ''
    const searchLower = searchQuery.toLowerCase()
    return productName.toLowerCase().includes(searchLower) || materialName.toLowerCase().includes(searchLower)
  })

  if (loading || !user) {
    return null
  }

  return (
    <ProtectedRoute allowedRoles={['admin']}>
      <div className="flex h-screen bg-gray-50">
        <Sidebar />
        <main className="flex-1 overflow-auto">
          <div className="p-8">
            <div className="flex items-center justify-between mb-8">
              <div>
                <h1 className="text-3xl font-bold text-gray-800">Resep Produk</h1>
                <p className="text-gray-600 mt-1">Kelola resep produk untuk perhitungan HPP</p>
              </div>
              <Dialog open={isDialogOpen} onOpenChange={(open) => {
                setIsDialogOpen(open)
                if (!open) resetForm()
              }}>
                <DialogTrigger>
                  <Button className="bg-gradient-to-r from-orange-500 to-red-500 hover:from-orange-600 hover:to-red-600">
                    <Plus className="w-4 h-4 mr-2" />
                    Tambah Resep
                  </Button>
                </DialogTrigger>
                <DialogContent className="sm:max-w-md">
                  <DialogHeader>
                    <DialogTitle>{editingRecipe ? 'Edit Resep' : 'Tambah Resep Baru'}</DialogTitle>
                  </DialogHeader>
                  <form onSubmit={handleSubmit} className="space-y-4">
                    <div>
                      <label className="text-sm font-medium text-gray-700">Produk</label>
                      <Select value={formData.product_id || ''} onValueChange={(value) => setFormData({ ...formData, product_id: value || '' })}>
                        <SelectTrigger>
                          <SelectValue placeholder="Pilih produk" />
                        </SelectTrigger>
                        <SelectContent>
                          {products.map((product) => (
                            <SelectItem key={product.id} value={product.id}>{product.name}</SelectItem>
                          ))}
                        </SelectContent>
                      </Select>
                    </div>
                    <div>
                      <label className="text-sm font-medium text-gray-700">Bahan Baku</label>
                      <Select value={formData.raw_material_id || ''} onValueChange={(value) => setFormData({ ...formData, raw_material_id: value || '' })}>
                        <SelectTrigger>
                          <SelectValue placeholder="Pilih bahan baku" />
                        </SelectTrigger>
                        <SelectContent>
                          {rawMaterials.map((material) => (
                            <SelectItem key={material.id} value={material.id}>{material.name} ({material.unit})</SelectItem>
                          ))}
                        </SelectContent>
                      </Select>
                    </div>
                    <div>
                      <label className="text-sm font-medium text-gray-700">Jumlah Digunakan</label>
                      <Input
                        type="number"
                        value={formData.quantity_used}
                        onChange={(e) => setFormData({ ...formData, quantity_used: e.target.value })}
                        required
                      />
                    </div>
                    <Button type="submit" className="w-full bg-gradient-to-r from-orange-500 to-red-500">
                      {editingRecipe ? 'Update' : 'Simpan'}
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
                      placeholder="Cari resep..."
                      value={searchQuery}
                      onChange={(e) => setSearchQuery(e.target.value)}
                      className="pl-10"
                    />
                  </div>
                </div>
              </CardHeader>
              <CardContent>
                <div className="overflow-x-auto">
                  <table className="w-full">
                    <thead>
                      <tr className="border-b border-gray-200">
                        <th className="text-left py-3 px-4 font-semibold text-gray-700">Produk</th>
                        <th className="text-left py-3 px-4 font-semibold text-gray-700">Bahan Baku</th>
                        <th className="text-left py-3 px-4 font-semibold text-gray-700">Jumlah</th>
                        <th className="text-left py-3 px-4 font-semibold text-gray-700">Biaya</th>
                        <th className="text-left py-3 px-4 font-semibold text-gray-700">Aksi</th>
                      </tr>
                    </thead>
                    <tbody>
                      {filteredRecipes.map((recipe) => {
                        const material = (recipe as any).raw_materials
                        const cost = material ? recipe.quantity_used * material.cost_per_unit : 0
                        return (
                          <tr key={recipe.id} className="border-b border-gray-100 hover:bg-gray-50">
                            <td className="py-3 px-4 font-medium text-gray-800">
                              {(recipe as any).products?.name || 'Unknown'}
                            </td>
                            <td className="py-3 px-4 text-gray-600">
                              {material?.name || 'Unknown'} ({material?.unit || ''})
                            </td>
                            <td className="py-3 px-4 text-gray-600">{recipe.quantity_used}</td>
                            <td className="py-3 px-4 text-gray-600">
                              Rp {cost.toLocaleString('id-ID')}
                            </td>
                            <td className="py-3 px-4">
                              <div className="flex gap-2">
                                <Button
                                  variant="ghost"
                                  size="sm"
                                  onClick={() => handleEdit(recipe)}
                                >
                                  <Edit className="w-4 h-4" />
                                </Button>
                                <Button
                                  variant="ghost"
                                  size="sm"
                                  onClick={() => handleDelete(recipe.id, recipe.product_id)}
                                >
                                  <Trash2 className="w-4 h-4 text-red-500" />
                                </Button>
                              </div>
                            </td>
                          </tr>
                        )
                      })}
                    </tbody>
                  </table>
                </div>
              </CardContent>
            </Card>
          </div>
        </main>
      </div>
    </ProtectedRoute>
  )
}
