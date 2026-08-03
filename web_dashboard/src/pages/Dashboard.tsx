import { useEffect, useState } from 'react'
import {
  AlertTriangle,
  Banknote,
  Inbox,
  PackageX,
  ReceiptText,
  ShoppingCart,
  TrendingUp,
  Trophy,
} from 'lucide-react'
import {
  Area,
  AreaChart,
  CartesianGrid,
  ResponsiveContainer,
  Tooltip,
  XAxis,
  YAxis,
} from 'recharts'
import { api, errMsg } from '../lib/api'
import { formatAngka, formatRupiah, formatRupiahCompact } from '../lib/format'
import type { MonthlyReport, ReportsSummary, StockAlert, TopProduct } from '../lib/types'
import { Badge, Card, EmptyState, ErrorState, SkeletonCard, Table, Td, Th, Thead, Tr } from '../components/ui'

const CARD_STYLES = [
  { icon: ReceiptText, bg: 'bg-primary/10 text-primary', label: 'Transaksi Hari Ini' },
  { icon: Banknote, bg: 'bg-success/10 text-success', label: 'Omzet Hari Ini' },
  { icon: TrendingUp, bg: 'bg-warning/10 text-warning', label: 'Omzet Bulan Ini' },
  { icon: ShoppingCart, bg: 'bg-slateBlue/10 text-slateBlue', label: 'Rata-rata Belanja' },
]

export default function Dashboard() {
  const [summary, setSummary] = useState<ReportsSummary | null>(null)
  const [dailyMap, setDailyMap] = useState<Record<string, number>>({})
  const [topProducts, setTopProducts] = useState<TopProduct[]>([])
  const [alerts, setAlerts] = useState<StockAlert[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)

  const load = async () => {
    setLoading(true)
    setError(null)
    try {
      const [sum, monthly, top, alertList] = await Promise.all([
        api<ReportsSummary>('/reports/summary'),
        api<MonthlyReport>('/reports/monthly'),
        api<TopProduct[]>('/reports/top-products?limit=10'),
        api<StockAlert[]>('/stock/alerts'),
      ])
      setSummary(sum)
      setDailyMap(monthly.daily)
      setTopProducts(top)
      setAlerts(alertList)
    } catch (e) {
      setError(errMsg(e))
    } finally {
      setLoading(false)
    }
  }

  useEffect(() => {
    load()
  }, [])

  const chartData = (() => {
    const days: { label: string; omzet: number }[] = []
    const today = new Date()
    for (let i = 6; i >= 0; i--) {
      const d = new Date(today.getFullYear(), today.getMonth(), today.getDate() - i)
      const key = `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`
      days.push({
        label: d.toLocaleDateString('id-ID', { day: 'numeric', month: 'short' }),
        omzet: dailyMap[key] ?? 0,
      })
    }
    return days
  })()

  if (loading) {
    return (
      <div className="space-y-6">
        <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 xl:grid-cols-4">
          <SkeletonCard />
          <SkeletonCard />
          <SkeletonCard />
          <SkeletonCard />
        </div>
        <div className="grid grid-cols-1 gap-4 lg:grid-cols-3">
          <SkeletonCard className="lg:col-span-2 h-80" />
          <SkeletonCard className="h-80" />
        </div>
        <SkeletonCard className="h-72" />
      </div>
    )
  }

  if (error) return <ErrorState message={error} onRetry={load} />

  const cards = [
    { label: 'Transaksi Hari Ini', value: formatAngka(summary?.today.total_transactions ?? 0), sub: 'transaksi' },
    { label: 'Omzet Hari Ini', value: formatRupiah(summary?.today.omzet ?? 0), sub: `${formatAngka(summary?.today.items_sold ?? 0)} item terjual` },
    { label: 'Omzet Bulan Ini', value: formatRupiah(summary?.this_month.omzet ?? 0), sub: `${formatAngka(summary?.this_month.total_transactions ?? 0)} transaksi` },
    { label: 'Rata-rata Belanja', value: formatRupiah(summary?.today.avg_belanja ?? 0), sub: 'per transaksi hari ini' },
  ]

  return (
    <div className="space-y-6">
      <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 xl:grid-cols-4">
        {cards.map((c, i) => {
          const style = CARD_STYLES[i]
          return (
            <Card key={c.label} className="p-5">
              <div className="flex items-start gap-4">
                <div className={`rounded-xl p-3 ${style.bg}`}>
                  <style.icon size={22} />
                </div>
                <div className="min-w-0">
                  <p className="text-xs font-medium text-textSecondary">{c.label}</p>
                  <p className="mt-1 truncate text-2xl font-bold text-textPrimary">{c.value}</p>
                  <p className="mt-0.5 text-xs text-textSecondary">{c.sub}</p>
                </div>
              </div>
            </Card>
          )
        })}
      </div>

      <div className="grid grid-cols-1 gap-4 lg:grid-cols-3">
        <Card className="p-5 lg:col-span-2">
          <div className="mb-4 flex items-center justify-between">
            <div>
              <h2 className="text-base font-bold text-textPrimary">Omzet 7 Hari Terakhir</h2>
              <p className="text-xs text-textSecondary">Total omzet harian bulan ini</p>
            </div>
            <Badge color="primary">{formatRupiah(chartData.reduce((a, b) => a + b.omzet, 0))}</Badge>
          </div>
          <div className="h-72">
            <ResponsiveContainer width="100%" height="100%">
              <AreaChart data={chartData} margin={{ top: 10, right: 10, left: 0, bottom: 0 }}>
                <defs>
                  <linearGradient id="omzetGradient" x1="0" y1="0" x2="0" y2="1">
                    <stop offset="0%" stopColor="#0D6E6E" stopOpacity={0.35} />
                    <stop offset="100%" stopColor="#0D6E6E" stopOpacity={0.02} />
                  </linearGradient>
                </defs>
                <CartesianGrid strokeDasharray="3 3" stroke="#E2E8F0" vertical={false} />
                <XAxis dataKey="label" tick={{ fontSize: 12, fill: '#64748B' }} axisLine={{ stroke: '#E2E8F0' }} tickLine={false} />
                <YAxis
                  tick={{ fontSize: 12, fill: '#64748B' }}
                  tickFormatter={(v: number) => formatRupiahCompact(v)}
                  axisLine={false}
                  tickLine={false}
                  width={70}
                />
                <Tooltip
                  formatter={(value: any) => [formatRupiah(Number(value)), 'Omzet']}
                  contentStyle={{ borderRadius: 12, border: '1px solid #E2E8F0', boxShadow: '0 2px 8px rgba(0,0,0,0.06)', fontSize: 13 }}
                />
                <Area type="monotone" dataKey="omzet" stroke="#0D6E6E" strokeWidth={2.5} fill="url(#omzetGradient)" />
              </AreaChart>
            </ResponsiveContainer>
          </div>
        </Card>

        <Card className="p-5">
          <div className="mb-4 flex items-center justify-between">
            <div>
              <h2 className="text-base font-bold text-textPrimary">Alert Stok</h2>
              <p className="text-xs text-textSecondary">Produk dengan stok menipis</p>
            </div>
            <Badge color={alerts.length > 0 ? 'red' : 'green'}>{alerts.length}</Badge>
          </div>
          {alerts.length === 0 ? (
            <EmptyState icon={PackageX} message="Semua stok aman" />
          ) : (
            <ul className="space-y-2">
              {alerts.map((a) => (
                <li key={a.id} className="flex items-center justify-between gap-3 rounded-lg border border-border bg-background/60 px-3 py-2.5">
                  <div className="min-w-0">
                    <p className="truncate text-sm font-medium text-textPrimary">{a.name}</p>
                    <p className="text-[11px] text-textSecondary">
                      {a.sku ? `SKU ${a.sku} · ` : ''}stok {formatAngka(a.stock, 2)} / ambang {formatAngka(a.stock_alert_threshold, 0)}
                    </p>
                  </div>
                  <Badge color={a.status === 'habis' ? 'red' : 'amber'}>{a.status === 'habis' ? 'Habis' : 'Menipis'}</Badge>
                </li>
              ))}
            </ul>
          )}
        </Card>
      </div>

      <Card>
        <div className="flex items-center gap-2 border-b border-border px-5 py-4">
          <Trophy size={18} className="text-warning" />
          <h2 className="text-base font-bold text-textPrimary">Top 10 Produk Terlaris</h2>
        </div>
        {topProducts.length === 0 ? (
          <EmptyState icon={Inbox} message="Belum ada data penjualan produk" />
        ) : (
          <Table className="border-0">
            <Thead>
              <Th className="w-12">No</Th>
              <Th>Produk</Th>
              <Th className="text-right">Qty Terjual</Th>
              <Th className="text-right">Revenue</Th>
            </Thead>
            <tbody>
              {topProducts.map((p, i) => (
                <Tr key={p.product_id}>
                  <Td className="w-12 text-textSecondary">{i + 1}</Td>
                  <Td>
                    <p className="font-medium text-textPrimary">{p.product_name}</p>
                  </Td>
                  <Td className="text-right font-semibold text-textPrimary">{formatAngka(p.qty_sold, 2)}</Td>
                  <Td className="text-right font-semibold text-success">{formatRupiah(p.revenue)}</Td>
                </Tr>
              ))}
            </tbody>
          </Table>
        )}
      </Card>

      {alerts.length > 0 && summary && summary.low_stock_count > 0 && (
        <div className="flex items-center gap-2 rounded-xl border border-warning/30 bg-warning/5 px-4 py-3 text-sm text-warning">
          <AlertTriangle size={16} />
          <span>{summary.low_stock_count} produk membutuhkan penambahan stok. Kelola di halaman Stok.</span>
        </div>
      )}
    </div>
  )
}
