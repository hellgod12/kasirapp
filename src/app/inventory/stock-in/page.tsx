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
import { supabase } from '@/lib/supabase'
import { Plus, Package } from 'lucide-react'

interface Product {
  id: string
  name: string
  category: string
  stock: number
}

export default function StockInPage() {
  const { user, loading } = useAuth()
  const router = useRouter()
  const [products, setProducts] = useState<Product[]>([])
  const [selectedProduct, setSelectedProduct] = useState<string>('')
  const [quantity, setQuantity] = useState('')
  const [notes, setNotes] = useState('')

  useEffect(() => {
    if (!loading && !user) {
      router.push('/login')
    }
  }, [user, loading, router])

  useEffect(() => {
    if (user) {
      fetchProducts()
    }
  }, [user])

  const fetchProducts = async () => {
    try {
      const { data, error } = await supabase
        .from('products')
        .select('*')
        .order('name')
      
      if (error) throw error
      setProducts(data || [])
    } catch (error) {
      console.error('Error fetching products:', error)
    }
  }

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    
    if (!selectedProduct || !quantity) {
      alert('Mohon lengkapi semua field')
      return
    }

    // Validate data
    const qty = parseInt(quantity)
    if (qty <= 0) {
      alert('Jumlah harus lebih dari 0')
      return
    }

    try {
      // Use atomic RPC function to prevent race conditions
      const { data, error } = await supabase.rpc('add_stock_atomic', {
        p_product_id: selectedProduct,
        p_quantity: qty,
        p_notes: notes || null,
        p_user_id: user!.id
      })

      if (error) throw error

      if (!data || !data.success) {
        throw new Error(data?.error || 'Failed to add stock')
      }

      alert(`Stok berhasil ditambahkan! Stok baru: ${data.new_stock}`)
      setSelectedProduct('')
      setQuantity('')
      setNotes('')
      fetchProducts()
    } catch (error) {
      console.error('Stock update error:', error)
      alert(`Terjadi kesalahan saat menambah stok: ${error instanceof Error ? error.message : 'Unknown error'}`)
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
            <h1 className="text-2xl md:text-3xl font-bold text-gray-800">Stok Masuk</h1>
            <p className="text-gray-600 mt-1 text-sm md:text-base">Catat stok barang masuk</p>
          </div>

          <Card className="shadow-lg max-w-2xl">
            <CardHeader>
              <CardTitle className="flex items-center gap-2">
                <Plus className="w-5 h-5 text-orange-500" />
                Tambah Stok Masuk
              </CardTitle>
            </CardHeader>
            <CardContent>
              <form onSubmit={handleSubmit} className="space-y-6">
                <div>
                  <label className="text-sm font-medium text-gray-700 mb-2 block">Produk</label>
                  <Select value={selectedProduct} onValueChange={(value) => setSelectedProduct(value || '')}>
                    <SelectTrigger>
                      <SelectValue placeholder="Pilih produk" />
                    </SelectTrigger>
                    <SelectContent>
                      {products.map((product) => (
                        <SelectItem key={product.id} value={product.id}>
                          {product.name} (Stok: {product.stock})
                        </SelectItem>
                      ))}
                    </SelectContent>
                  </Select>
                </div>

                <div>
                  <label className="text-sm font-medium text-gray-700 mb-2 block">Jumlah</label>
                  <Input
                    type="number"
                    placeholder="Masukkan jumlah"
                    value={quantity}
                    onChange={(e) => setQuantity(e.target.value)}
                    min="1"
                    required
                  />
                </div>

                <div>
                  <label className="text-sm font-medium text-gray-700 mb-2 block">Catatan (opsional)</label>
                  <Input
                    placeholder="Catatan tambahan"
                    value={notes}
                    onChange={(e) => setNotes(e.target.value)}
                  />
                </div>

                <Button
                  type="submit"
                  className="w-full h-12 bg-gradient-to-r from-orange-500 to-red-500 hover:from-orange-600 hover:to-red-600 text-white font-semibold shadow-md"
                >
                  Simpan Stok Masuk
                </Button>
              </form>
            </CardContent>
          </Card>
        </div>
      </main>
      <MobileNavigation />
    </div>
    </ProtectedRoute>
  )
}
