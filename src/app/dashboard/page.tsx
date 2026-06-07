'use client'

import { useEffect, useState } from 'react'
import { useAuth } from '@/contexts/AuthContext'
import { useRouter } from 'next/navigation'
import { Sidebar } from '@/components/Sidebar'
import { MobileNavigation } from '@/components/MobileNavigation'
import { ProtectedRoute } from '@/components/ProtectedRoute'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card'
import { 
  DollarSign, 
  TrendingUp, 
  ShoppingCart, 
  AlertTriangle,
  Cake,
  Wallet,
  CreditCard,
  Package,
  Receipt
} from 'lucide-react'
import { supabase } from '@/lib/supabase'
import { format } from 'date-fns'
import { id } from 'date-fns/locale'

interface DashboardStats {
  todayRevenue: number
  todayHPP: number
  todayProfit: number
  todayExpenses: number
  todayNetProfit: number
  todaySales: number
  todayCashSales: number
  todayTransferSales: number
  todayTransactionCount: number
  lowStock: number
  bestSellers: any[]
}

export default function DashboardPage() {
  const { user, loading } = useAuth()
  const router = useRouter()
  const [stats, setStats] = useState<DashboardStats>({
    todayRevenue: 0,
    todayHPP: 0,
    todayProfit: 0,
    todayExpenses: 0,
    todayNetProfit: 0,
    todaySales: 0,
    todayCashSales: 0,
    todayTransferSales: 0,
    todayTransactionCount: 0,
    lowStock: 0,
    bestSellers: []
  })
  const [isLoading, setIsLoading] = useState(true)

  useEffect(() => {
    if (!loading && !user) {
      router.push('/login')
    }
  }, [user, loading, router])

  useEffect(() => {
    if (user) {
      fetchDashboardStats()
    }
  }, [user])

  const fetchDashboardStats = async () => {
    try {
      // Use UTC date to match Supabase's timezone
      const now = new Date()
      const todayUTC = new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate()))
      const tomorrowUTC = new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate() + 1))
      
      const todayStart = todayUTC.toISOString()
      const todayEnd = tomorrowUTC.toISOString()

      console.log('DASHBOARD DATE RANGE:', { todayStart, todayEnd })

      // Get today's sale items for accurate profit calculation
      const { data: saleItemsData } = await supabase
        .from('sale_items')
        .select('subtotal, cost, quantity')
        .gte('created_at', todayStart)
        .lt('created_at', todayEnd)

      console.log('TODAY SALE ITEMS DATA:', saleItemsData)

      // Calculate revenue from sale_items (sum of subtotals)
      const todayRevenue = saleItemsData?.reduce((sum, item) => sum + Number(item.subtotal), 0) || 0
      console.log('TODAY REVENUE (from sale_items subtotal):', todayRevenue)

      // Calculate cost from sale_items (sum of cost * quantity)
      const todayCost = saleItemsData?.reduce((sum, item) => sum + (Number(item.cost) * Number(item.quantity)), 0) || 0
      console.log('TODAY COST (from sale_items cost * quantity):', todayCost)

      // Calculate profit (revenue - cost)
      const todayProfit = todayRevenue - todayCost
      console.log('TODAY PROFIT (revenue - cost):', todayProfit)

      // Calculate cash and transfer sales from sales table
      const { data: salesData } = await supabase
        .from('sales')
        .select('total_amount, payment_method')
        .gte('created_at', todayStart)
        .lt('created_at', todayEnd)

      const todayCashSales = salesData?.filter(sale => sale.payment_method === 'cash').reduce((sum, sale) => sum + Number(sale.total_amount), 0) || 0
      const todayTransferSales = salesData?.filter(sale => sale.payment_method === 'transfer').reduce((sum, sale) => sum + Number(sale.total_amount), 0) || 0
      const todayTransactionCount = salesData?.length || 0

      console.log('TODAY CASH SALES:', todayCashSales)
      console.log('TODAY TRANSFER SALES:', todayTransferSales)
      console.log('TODAY TRANSACTION COUNT:', todayTransactionCount)

      // Get today's total quantity sold (sum of all sale_items quantities)
      const todayQuantitySold = saleItemsData?.reduce((sum, item) => sum + Number(item.quantity), 0) || 0
      console.log('TODAY QUANTITY SOLD:', todayQuantitySold)

      // Get low stock products (stock < 10)
      const { count: lowStockCount } = await supabase
        .from('products')
        .select('*', { count: 'exact', head: true })
        .lt('stock', 10)

      // Get best sellers (top 5 by quantity sold TODAY)
      const { data: bestSellersRawData } = await supabase
        .from('sale_items')
        .select('product_id, quantity, products!inner(name)')
        .gte('created_at', todayStart)
        .lt('created_at', todayEnd)

      // Aggregate by product_id and sum quantities
      const productAggregates = new Map<string, { quantity: number, name: string }>()
      bestSellersRawData?.forEach(item => {
        const productId = item.product_id
        const current = productAggregates.get(productId) || { quantity: 0, name: (item as any).products?.name || 'Unknown' }
        productAggregates.set(productId, {
          quantity: current.quantity + Number(item.quantity),
          name: current.name
        })
      })

      // Convert to array, sort by quantity descending, and take top 5
      const bestSellersData = Array.from(productAggregates.entries())
        .map(([product_id, data]) => ({
          product_id,
          quantity: data.quantity,
          products: { name: data.name }
        }))
        .sort((a, b) => b.quantity - a.quantity)
        .slice(0, 5)

      console.log('TODAY BEST SELLERS:', bestSellersData)

      // Get today's expenses
      const { data: expensesData } = await supabase
        .from('expenses')
        .select('amount')
        .gte('expense_date', todayUTC.toISOString().split('T')[0])
        .lte('expense_date', tomorrowUTC.toISOString().split('T')[0])

      const todayExpenses = expensesData?.reduce((sum, expense) => sum + Number(expense.amount), 0) || 0
      const todayNetProfit = todayProfit - todayExpenses

      console.log('TODAY EXPENSES:', todayExpenses)
      console.log('TODAY NET PROFIT:', todayNetProfit)

      setStats({
        todayRevenue,
        todayHPP: todayCost,
        todayProfit,
        todayExpenses,
        todayNetProfit,
        todaySales: todayQuantitySold,
        todayCashSales,
        todayTransferSales,
        todayTransactionCount,
        lowStock: lowStockCount || 0,
        bestSellers: bestSellersData || []
      })
    } catch (error) {
      console.error('Error fetching dashboard stats:', error)
    } finally {
      setIsLoading(false)
    }
  }

  const statCards = [
    {
      title: 'Omzet Hari Ini',
      value: `Rp ${stats.todayRevenue.toLocaleString('id-ID')}`,
      icon: DollarSign,
      color: 'from-orange-500 to-red-500',
      bgColor: 'bg-orange-50'
    },
    {
      title: 'HPP Hari Ini',
      value: `Rp ${stats.todayHPP.toLocaleString('id-ID')}`,
      icon: Package,
      color: 'from-amber-500 to-yellow-500',
      bgColor: 'bg-amber-50'
    },
    {
      title: 'Laba Kotor Hari Ini',
      value: `Rp ${stats.todayProfit.toLocaleString('id-ID')}`,
      icon: TrendingUp,
      color: 'from-green-500 to-emerald-500',
      bgColor: 'bg-green-50'
    },
    {
      title: 'Pengeluaran Hari Ini',
      value: `Rp ${stats.todayExpenses.toLocaleString('id-ID')}`,
      icon: Wallet,
      color: 'from-red-500 to-pink-500',
      bgColor: 'bg-red-50'
    },
    {
      title: 'Laba Bersih Hari Ini',
      value: `Rp ${stats.todayNetProfit.toLocaleString('id-ID')}`,
      icon: TrendingUp,
      color: 'from-blue-500 to-indigo-500',
      bgColor: 'bg-blue-50'
    },
    {
      title: 'Penjualan Tunai Hari Ini',
      value: `Rp ${stats.todayCashSales.toLocaleString('id-ID')}`,
      icon: Wallet,
      color: 'from-teal-500 to-cyan-500',
      bgColor: 'bg-teal-50'
    },
    {
      title: 'Penjualan Transfer Hari Ini',
      value: `Rp ${stats.todayTransferSales.toLocaleString('id-ID')}`,
      icon: CreditCard,
      color: 'from-purple-500 to-violet-500',
      bgColor: 'bg-purple-50'
    },
    {
      title: 'Jumlah Transaksi Hari Ini',
      value: stats.todayTransactionCount.toString(),
      icon: Receipt,
      color: 'from-indigo-500 to-blue-500',
      bgColor: 'bg-indigo-50'
    },
    {
      title: 'Produk Terjual',
      value: stats.todaySales.toString(),
      icon: ShoppingCart,
      color: 'from-pink-500 to-rose-500',
      bgColor: 'bg-pink-50'
    },
    {
      title: 'Stok Menipis',
      value: stats.lowStock.toString(),
      icon: AlertTriangle,
      color: 'from-yellow-500 to-orange-500',
      bgColor: 'bg-yellow-50'
    }
  ]

  if (loading || !user) {
    return null
  }

  return (
    <ProtectedRoute allowedRoles={['admin', 'kasir']}>
      <div className="flex h-screen bg-gray-50">
        <Sidebar />
        <main className="flex-1 overflow-auto pb-20 md:pb-0">
          <div className="p-4 md:p-8">
            <div className="mb-6 md:mb-8">
              <h1 className="text-2xl md:text-3xl font-bold text-gray-800">Dashboard</h1>
              <p className="text-gray-600 mt-1 text-sm md:text-base">
                Selamat datang kembali, {user!.name}!
              </p>
            </div>

            {/* Stats Cards */}
            <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4 md:gap-6 mb-6 md:mb-8">
              {statCards.map((stat) => (
                <Card key={stat.title} className="shadow-lg hover:shadow-xl transition-shadow duration-300">
                  <CardHeader className="flex flex-row items-center justify-between pb-2">
                    <CardTitle className="text-sm font-medium text-gray-600">
                      {stat.title}
                    </CardTitle>
                    <div className={`p-2 rounded-lg bg-gradient-to-br ${stat.color}`}>
                      <stat.icon className="w-5 h-5 text-white" />
                    </div>
                  </CardHeader>
                  <CardContent>
                    <div className="text-2xl font-bold text-gray-800">{stat.value}</div>
                  </CardContent>
                </Card>
              ))}
            </div>

            {/* Best Sellers */}
            <Card className="shadow-lg">
              <CardHeader>
                <CardTitle className="flex items-center gap-2">
                  <Cake className="w-5 h-5 text-orange-500" />
                  Produk Terlaris
                </CardTitle>
              </CardHeader>
              <CardContent>
                {stats.bestSellers.length > 0 ? (
                  <div className="space-y-4">
                    {stats.bestSellers.map((item, index) => (
                      <div
                        key={index}
                        className="flex items-center justify-between p-4 bg-gradient-to-r from-orange-50 to-white rounded-lg border border-orange-100"
                      >
                        <div className="flex items-center gap-4">
                          <div className="w-8 h-8 bg-gradient-to-br from-orange-500 to-red-500 rounded-full flex items-center justify-center text-white font-bold text-sm">
                            {index + 1}
                          </div>
                          <div>
                            <p className="font-semibold text-gray-800">
                              {(item as any).products?.name || 'Unknown'}
                            </p>
                            <p className="text-sm text-gray-500">
                              {item.quantity} terjual
                            </p>
                          </div>
                        </div>
                      </div>
                    ))}
                  </div>
                ) : (
                  <div className="text-center py-8 text-gray-500">
                    Belum ada data penjualan
                  </div>
                )}
              </CardContent>
            </Card>
          </div>
        </main>
        <MobileNavigation />
      </div>
    </ProtectedRoute>
  )
}
