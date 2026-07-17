'use client'

import { useEffect, useState } from 'react'
import { useAuth } from '@/contexts/AuthContext'
import { useRouter } from 'next/navigation'
import { Sidebar } from '@/components/Sidebar'
import { MobileNavigation } from '@/components/MobileNavigation'
import { ProtectedRoute } from '@/components/ProtectedRoute'
import { Card, CardContent } from '@/components/ui/card'
import { Button } from '@/components/ui/button'
import { Badge } from '@/components/ui/badge'
import { ScrollArea } from '@/components/ui/scroll-area'
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select'
import { Skeleton } from '@/components/ui/skeleton'
import { useStore } from '@/store/useStore'
import { supabase } from '@/lib/supabase'
import { Plus, Minus, Trash2, ShoppingBag, Cake, Coffee, Cookie, Package } from 'lucide-react'
import { format } from 'date-fns'
import { id } from 'date-fns/locale'

interface Product {
  id: string
  name: string
  category: string
  price: number
  cost: number
  hpp: number
  stock: number
  image_url: string | null
  is_active: boolean
  barcode: string | null
}

interface Category {
  id: string
  name: string
  icon: string
  color: string
  is_active: boolean
}

interface PaymentMethod {
  id: string
  name: string
  code: string
  is_active: boolean
}

interface Setting {
  key: string
  value: string
}

export default function POSPage() {
  const { user, loading } = useAuth()
  const router = useRouter()
  const [products, setProducts] = useState<Product[]>([])
  const [categories, setCategories] = useState<Category[]>([])
  const [paymentMethods, setPaymentMethods] = useState<PaymentMethod[]>([])
  const [settings, setSettings] = useState<Setting[]>([])
  const [selectedCategory, setSelectedCategory] = useState<string>('all')
  const [searchQuery, setSearchQuery] = useState('')
  const [barcodeInput, setBarcodeInput] = useState('')
  const [isProcessing, setIsProcessing] = useState(false)
  const [paymentMethod, setPaymentMethod] = useState<string>('cash')
  const [selectedCustomer, setSelectedCustomer] = useState<string | null>(null)
  const [selectedDiscount, setSelectedDiscount] = useState<string | null>(null)
  const [customers, setCustomers] = useState<any[]>([])
  const [activeDiscounts, setActiveDiscounts] = useState<any[]>([])
  const [hasUnsavedChanges, setHasUnsavedChanges] = useState(false)
  const [isCheckoutDisabled, setIsCheckoutDisabled] = useState(false)
  
  const { cart, addToCart, removeFromCart, updateQuantity, clearCart, getCartTotal, getCartCount } = useStore()

  useEffect(() => {
    if (!loading && !user) {
      router.push('/login')
    }
  }, [user, loading, router])

  useEffect(() => {
    if (user) {
      fetchProducts()
      fetchCategories()
      fetchPaymentMethods()
      fetchSettings()
      fetchCustomers()
      fetchActiveDiscounts()
    }
  }, [user])

  // Refresh protection - warn user before leaving if cart has items
  useEffect(() => {
    const handleBeforeUnload = (e: BeforeUnloadEvent) => {
      if (cart.length > 0 || isProcessing) {
        e.preventDefault()
        e.returnValue = '' // Chrome requires returnValue to be set
        return ''
      }
    }

    window.addEventListener('beforeunload', handleBeforeUnload)

    return () => {
      window.removeEventListener('beforeunload', handleBeforeUnload)
    }
  }, [cart.length, isProcessing])

  const fetchCategories = async () => {
    try {
      const { data, error } = await supabase
        .from('categories')
        .select('*')
        .eq('is_active', true)
        .order('sort_order')
      
      if (error) throw error
      setCategories(data || [])
    } catch (error) {
      console.error('Error fetching categories:', error)
    }
  }

  const fetchPaymentMethods = async () => {
    try {
      const { data, error } = await supabase
        .from('payment_methods')
        .select('*')
        .eq('is_active', true)
        .order('sort_order')
      
      if (error) throw error
      setPaymentMethods(data || [])
      
      // Set default payment method to first active method
      if (data && data.length > 0 && !paymentMethod) {
        setPaymentMethod(data[0].code)
      }
    } catch (error) {
      console.error('Error fetching payment methods:', error)
    }
  }

  const fetchSettings = async () => {
    try {
      const { data, error } = await supabase
        .from('settings')
        .select('*')
      
      if (error) throw error
      setSettings(data || [])
    } catch (error) {
      console.error('Error fetching settings:', error)
    }
  }

  const fetchCustomers = async () => {
    try {
      const { data, error } = await supabase
        .from('customers')
        .select('*')
        .eq('is_active', true)
        .order('name')
      
      if (error) throw error
      setCustomers(data || [])
    } catch (error) {
      console.error('Error fetching customers:', error)
    }
  }

  const fetchActiveDiscounts = async () => {
    try {
      const { data, error } = await supabase
        .from('discounts')
        .select('*')
        .eq('is_active', true)
        .order('name')
      
      if (error) throw error
      setActiveDiscounts(data || [])
    } catch (error) {
      console.error('Error fetching discounts:', error)
    }
  }

  const getSettingValue = (key: string, defaultValue: string = '10'): string => {
    const setting = settings.find(s => s.key === key)
    return setting?.value || defaultValue
  }

  const getLowStockThreshold = (): number => {
    return parseInt(getSettingValue('low_stock_threshold', '10'))
  }

  const getIconComponent = (iconName: string) => {
    switch (iconName) {
      case 'Cake': return Cake
      case 'Coffee': return Coffee
      case 'Cookie': return Cookie
      default: return Package
    }
  }

  const fetchProducts = async () => {
    try {
      const { data, error } = await supabase
        .from('products')
        .select('*')
        .eq('is_active', true)
        .order('name')
      
      if (error) throw error
      setProducts(data || [])
    } catch (error) {
      console.error('Error fetching products:', error)
    }
  }

  const handleAddToCart = (product: Product) => {
    if (product.stock <= 0) {
      alert('Stok habis!')
      return
    }
    
    const existingItem = cart.find(item => item.id === product.id)
    const currentQuantity = existingItem?.quantity || 0
    
    if (currentQuantity >= product.stock) {
      alert('Stok tidak mencukupi!')
      return
    }
    
    addToCart({
      id: product.id,
      name: product.name,
      category: product.category,
      price: product.price,
      cost: product.cost,
      hpp: product.hpp || product.cost,
      quantity: 1
    })
  }

  const handleBarcodeInput = async (e: React.KeyboardEvent<HTMLInputElement>) => {
    if (e.key === 'Enter' && barcodeInput.trim()) {
      const barcode = barcodeInput.trim()
      const product = products.find(p => p.barcode === barcode)
      
      if (product) {
        handleAddToCart(product)
        setBarcodeInput('')
      } else {
        alert('Produk tidak ditemukan dengan barcode ini')
      }
    }
  }

  const handleCheckout = async () => {
    if (cart.length === 0) {
      alert('Keranjang kosong!')
      return
    }

    if (isCheckoutDisabled) {
      alert('Transaksi sedang diproses. Mohon tunggu.')
      return
    }

    setIsProcessing(true)
    setIsCheckoutDisabled(true)
    try {
      // Generate unique transaction token for duplicate prevention
      const transactionToken = `${user!.id}-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`
      
      // Prepare items array for RPC function
      const items = cart.map(item => ({
        product_id: item.id,
        quantity: item.quantity,
        price: item.price,
        cost: item.hpp || item.cost
      }))

      // Call atomic checkout RPC function
      const { data, error } = await supabase.rpc('process_checkout', {
        p_items: items,
        p_payment_method: paymentMethod,
        p_user_id: user!.id,
        p_transaction_token: transactionToken,
        p_customer_id: selectedCustomer,
        p_discount_id: selectedDiscount
      })

      if (error) throw error

      if (!data || !data.success) {
        throw new Error(data?.error || 'Checkout failed')
      }

      clearCart()
      setSelectedCustomer(null)
      setSelectedDiscount(null)
      alert('Transaksi berhasil!')
      fetchProducts()
    } catch (error) {
      alert(`Terjadi kesalahan saat memproses transaksi: ${error instanceof Error ? error.message : 'Unknown error'}`)
    } finally {
      setIsProcessing(false)
      setIsCheckoutDisabled(false)
    }
  }

  const filteredProducts = products.filter(product => {
    const matchesCategory = selectedCategory === 'all' || product.category === selectedCategory
    const matchesSearch = product.name.toLowerCase().includes(searchQuery.toLowerCase())
    return matchesCategory && matchesSearch
  })

  if (loading || !user) {
    return null
  }

  return (
    <ProtectedRoute allowedRoles={['admin', 'kasir']}>
      <div className="flex h-screen bg-gray-50">
        <Sidebar />
        <main className="flex-1 overflow-auto pb-20 md:pb-0">
          <div className="flex flex-col md:flex-row h-full">
            {/* Left Panel - Categories - Hidden on mobile */}
            <div className="hidden md:block w-64 bg-white border-r border-gray-200 p-4">
              <h2 className="text-lg font-bold text-gray-800 mb-4">Kategori</h2>
              <div className="space-y-2">
                <Button
                  variant={selectedCategory === 'all' ? 'default' : 'outline'}
                  className="w-full justify-start"
                  onClick={() => setSelectedCategory('all')}
                >
                  Semua
                </Button>
                {categories.map((category) => {
                  const Icon = getIconComponent(category.icon)
                  return (
                    <Button
                      key={category.id}
                      variant={selectedCategory === category.name ? 'default' : 'outline'}
                      className="w-full justify-start capitalize"
                      onClick={() => setSelectedCategory(category.name)}
                    >
                      <Icon className="w-4 h-4 mr-2" />
                      {category.name}
                    </Button>
                  )
                })}
              </div>
            </div>

            {/* Middle Panel - Products */}
            <div className="flex-1 p-4 md:p-6">
              {/* Mobile Category Tabs */}
              <div className="md:hidden mb-4 overflow-x-auto pb-2">
                <div className="flex gap-2">
                  <Button
                    variant={selectedCategory === 'all' ? 'default' : 'outline'}
                    size="sm"
                    onClick={() => setSelectedCategory('all')}
                  >
                    Semua
                  </Button>
                  {categories.map((category) => {
                    const Icon = getIconComponent(category.icon)
                    return (
                      <Button
                        key={category.id}
                        variant={selectedCategory === category.name ? 'default' : 'outline'}
                        size="sm"
                        className="capitalize whitespace-nowrap"
                        onClick={() => setSelectedCategory(category.name)}
                      >
                        <Icon className="w-4 h-4 mr-1" />
                        {category.name}
                      </Button>
                    )
                  })}
                </div>
              </div>

              <div className="mb-4 md:mb-6 space-y-2">
                <input
                  type="text"
                  placeholder="Cari produk..."
                  value={searchQuery}
                  onChange={(e) => setSearchQuery(e.target.value)}
                  className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-orange-500"
                />
                <input
                  type="text"
                  placeholder="Scan barcode (tekan Enter)..."
                  value={barcodeInput}
                  onChange={(e) => setBarcodeInput(e.target.value)}
                  onKeyDown={handleBarcodeInput}
                  className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-orange-500 bg-orange-50"
                />
              </div>
              
              <div className="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-4 gap-3 md:gap-4">
                {loading ? (
                  [...Array(8)].map((_, i) => (
                    <Card key={i} className="overflow-hidden">
                      <Skeleton className="h-32 w-full" />
                      <CardContent className="p-4">
                        <Skeleton className="h-5 w-3/4 mb-2" />
                        <Skeleton className="h-4 w-1/2 mb-2" />
                        <div className="flex justify-between">
                          <Skeleton className="h-4 w-1/3" />
                          <Skeleton className="h-4 w-1/4" />
                        </div>
                      </CardContent>
                    </Card>
                  ))
                ) : filteredProducts.length === 0 ? (
                  <div className="col-span-full text-center py-8 text-gray-500">
                    Tidak ada produk ditemukan
                  </div>
                ) : (
                  filteredProducts.map((product) => {
                    const category = categories.find(c => c.name === product.category)
                    const Icon = category ? getIconComponent(category.icon) : Package
                    const categoryColor = category?.color || 'from-gray-500 to-gray-600'
                    const lowStockThreshold = getLowStockThreshold()
                    
                    return (
                      <Card
                        key={product.id}
                        className="cursor-pointer hover:shadow-lg transition-shadow duration-300 overflow-hidden"
                        onClick={() => handleAddToCart(product)}
                      >
                        <div className={`h-32 bg-gradient-to-br ${categoryColor} flex items-center justify-center`}>
                          <Icon className="w-16 h-16 text-white opacity-80" />
                        </div>
                        <CardContent className="p-4">
                          <h3 className="font-semibold text-gray-800 mb-1 truncate">{product.name}</h3>
                          <p className="text-sm text-gray-500 capitalize mb-2">{product.category}</p>
                          <div className="flex items-center justify-between">
                            <span className="font-bold text-orange-600">
                              Rp {product.price.toLocaleString('id-ID')}
                            </span>
                            <Badge variant={product.stock < lowStockThreshold ? 'destructive' : 'secondary'}>
                              Stok: {product.stock}
                            </Badge>
                          </div>
                        </CardContent>
                      </Card>
                    )
                  })
                )}
              </div>
            </div>

            {/* Right Panel - Cart */}
            <div className="w-full md:w-96 bg-white border-l border-gray-200 flex flex-col">
              <div className="p-4 border-b border-gray-200">
                <h2 className="text-lg font-bold text-gray-800 flex items-center gap-2">
                  <ShoppingBag className="w-5 h-5 text-orange-500" />
                  Keranjang
                </h2>
              </div>
              
              <ScrollArea className="flex-1 p-4">
                {cart.length === 0 ? (
                  <div className="text-center py-8 text-gray-500">
                    Keranjang kosong
                  </div>
                ) : (
                  <div className="space-y-4">
                    {cart.map((item) => (
                      <Card key={item.id} className="p-4">
                        <div className="flex items-start justify-between mb-2">
                          <div className="flex-1">
                            <h4 className="font-semibold text-gray-800">{item.name}</h4>
                            <p className="text-sm text-gray-500">
                              Rp {item.price.toLocaleString('id-ID')}
                            </p>
                          </div>
                          <Button
                            variant="ghost"
                            size="sm"
                            onClick={() => removeFromCart(item.id)}
                          >
                            <Trash2 className="w-4 h-4 text-red-500" />
                          </Button>
                        </div>
                        <div className="flex items-center justify-between">
                          <div className="flex items-center gap-2">
                            <Button
                              variant="outline"
                              size="sm"
                              onClick={() => updateQuantity(item.id, Math.max(1, item.quantity - 1))}
                            >
                              <Minus className="w-4 h-4" />
                            </Button>
                            <span className="w-8 text-center font-semibold">{item.quantity}</span>
                            <Button
                              variant="outline"
                              size="sm"
                              onClick={() => updateQuantity(item.id, item.quantity + 1)}
                            >
                              <Plus className="w-4 h-4" />
                            </Button>
                          </div>
                          <span className="font-bold text-orange-600">
                            Rp {(item.price * item.quantity).toLocaleString('id-ID')}
                          </span>
                        </div>
                      </Card>
                    ))}
                  </div>
                )}
              </ScrollArea>

              <div className="p-4 border-t border-gray-200 space-y-4">
                <div className="space-y-2">
                  <div className="flex justify-between text-sm">
                    <span className="text-gray-600">Jumlah Item</span>
                    <span className="font-semibold">{getCartCount()}</span>
                  </div>
                  <div className="flex justify-between text-lg font-bold">
                    <span className="text-gray-800">Total</span>
                    <span className="text-orange-600">
                      Rp {getCartTotal().toLocaleString('id-ID')}
                    </span>
                  </div>
                </div>
                <div className="space-y-2">
                  <label className="text-sm font-medium text-gray-700">
                    Pelanggan (Opsional)
                  </label>
                  <Select value={selectedCustomer || ''} onValueChange={(value: string | null) => setSelectedCustomer(value)}>
                    <SelectTrigger className="h-11">
                      <SelectValue placeholder="Pilih pelanggan" />
                    </SelectTrigger>
                    <SelectContent>
                      <SelectItem value="">Tanpa Pelanggan</SelectItem>
                      {customers.map((customer) => (
                        <SelectItem key={customer.id} value={customer.id}>
                          {customer.name}
                        </SelectItem>
                      ))}
                    </SelectContent>
                  </Select>
                </div>
                <div className="space-y-2">
                  <label className="text-sm font-medium text-gray-700">
                    Diskon (Opsional)
                  </label>
                  <Select value={selectedDiscount || ''} onValueChange={(value: string | null) => setSelectedDiscount(value)}>
                    <SelectTrigger className="h-11">
                      <SelectValue placeholder="Pilih diskon" />
                    </SelectTrigger>
                    <SelectContent>
                      <SelectItem value="">Tanpa Diskon</SelectItem>
                      {activeDiscounts.map((discount) => (
                        <SelectItem key={discount.id} value={discount.id}>
                          {discount.name} ({discount.type === 'percentage' ? `${discount.value}%` : `Rp ${discount.value.toLocaleString('id-ID')}`})
                        </SelectItem>
                      ))}
                    </SelectContent>
                  </Select>
                </div>
                <div className="space-y-2">
                  <label className="text-sm font-medium text-gray-700">
                    Metode Pembayaran
                  </label>
                  <Select value={paymentMethod} onValueChange={(value: string | null) => setPaymentMethod(value || 'cash')}>
                    <SelectTrigger className="h-11">
                      <SelectValue placeholder="Pilih metode pembayaran" />
                    </SelectTrigger>
                    <SelectContent>
                      {paymentMethods.map((method) => (
                        <SelectItem key={method.id} value={method.code}>
                          {method.name}
                        </SelectItem>
                      ))}
                    </SelectContent>
                  </Select>
                </div>
                <Button
                  className="w-full h-12 bg-gradient-to-r from-orange-500 to-red-500 hover:from-orange-600 hover:to-red-600 text-white font-semibold shadow-md"
                  onClick={handleCheckout}
                  disabled={cart.length === 0 || isProcessing}
                >
                  {isProcessing ? 'Memproses...' : 'Bayar'}
                </Button>
              </div>
            </div>
          </div>
        </main>
        <MobileNavigation />
      </div>
    </ProtectedRoute>
  )
}
