import { useCallback, useEffect, useMemo, useState } from 'react'
import {
  Banknote,
  BarChart3,
  CalendarRange,
  FileSpreadsheet,
  FileText,
  Inbox,
  ReceiptText,
  TrendingUp,
} from 'lucide-react'
import {
  Bar,
  BarChart,
  CartesianGrid,
  ResponsiveContainer,
  Tooltip,
  XAxis,
  YAxis,
} from 'recharts'
import { api, errMsg, getToken } from '../lib/api'
import { formatAngka, formatRupiah, formatRupiahCompact, formatTanggalWaktu } from '../lib/format'
import type { DailyReport, MonthlyReport, Transaction, TransactionListResponse } from '../lib/types'
import {
  Badge,
  Card,
  EmptyState,
  ErrorState,
  Input,
  SkeletonCard,
  Table,
  Td,
  Th,
  Thead,
  Tr,
} from '../components/ui'

const METHOD_LABELS: Record<string, string> = {
  tunai: 'Tunai',
  qris: 'QRIS',
  ewallet: 'E-Wallet',
  split: 'Split',
  utang: 'Utang',
}

const METHOD_COLORS: Record<string, 'slate' | 'primary' | 'success' | 'warning' | 'danger'> = {
  tunai: 'slate',
  qris: 'primary',
  ewallet: 'success',
  split: 'warning',
  utang: 'danger',
}

function statusBadge(status: string) {
  if (status === 'selesai') return <Badge color="green">Selesai</Badge>
  if (status === 'retur') return <Badge color="warning">Retur</Badge>
  return <Badge color="red">Void</Badge>
}

const todayISO = (): string => {
  const d = new Date()
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`
}

const daysAgoISO = (n: number): string => {
  const d = new Date()
  d.setDate(d.getDate() - n)
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`
}

export default function Reports() {
  const [from, setFrom] = useState(daysAgoISO(29))
  const [to, setTo] = useState(todayISO())
  const [daily, setDaily] = useState<DailyReport | null>(null)
  const [monthly, setMonthly] = useState<MonthlyReport | null>(null)
  const [transactions, setTransactions] = useState<Transaction[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)
  const [exporting, setExporting] = useState<string | null>(null)

  const handleExport = async (format: 'xlsx' | 'pdf') => {
    setExporting(format)
    try {
      const token = getToken()
      const res = await fetch(`/reports/export?format=${format}&date_from=${from}&date_to=${to}`, {
        headers: token ? { Authorization: `Bearer ${token}` } : {},
      })
      if (!res.ok) throw new Error(`Export gagal (${res.status})`)
      const blob = await res.blob()
      const url = URL.createObjectURL(blob)
      const a = document.createElement('a')
      a.href = url
      a.download = `laporan_kiosku_${from}_${to}.${format}`
      document.body.appendChild(a)
      a.click()
      document.body.removeChild(a)
      URL.revokeObjectURL(url)
    } catch (e) {
      setError(errMsg(e))
    } finally {
      setExporting(null)
    }
  }

  const load = useCallback(async () => {
    if (!from || !to) return
    setLoading(true)
    setError(null)
    try {
      const [dayRep, monthRep, txRes] = await Promise.all([
        api<DailyReport>(`/reports/daily?dt=${from}`),
        api<MonthlyReport>('/reports/monthly'),
        api<TransactionListResponse>(`/transactions?date_from=${from}&date_to=${to}&page_size=100`),
      ])
      setDaily(dayRep)
      setMonthly(monthRep)
      setTransactions(txRes.items)
    } catch (e) {
      setError(errMsg(e))
    } finally {
      setLoading(false)
    }
  }, [from, to])

  useEffect(() => {
    load()
  }, [load])

  const chartData = useMemo(() => {
    const byDay: Record<string, number> = {}
    for (const t of transactions) {
      const day = (t.created_at ?? '').slice(0, 10)
      if (day) byDay[day] = Math.round(((byDay[day] ?? 0) + t.total_amount) * 100) / 100
    }
    return Object.entries(byDay)
      .sort((a, b) => a[0].localeCompare(b[0]))
      .map(([day, omzet]) => {
        const d = new Date(`${day}T00:00:00`)
        return { label: d.toLocaleDateString('id-ID', { day: 'numeric', month: 'short' }), omzet }
      })
  }, [transactions])

  const rangeSummary = useMemo(() => {
    let omzet = 0
    let items = 0
    for (const t of transactions) {
      omzet += t.total_amount
      items += t.items.reduce((a, i) => a + i.qty, 0)
    }
    return { omzet: Math.round(omzet * 100) / 100, items }
  }, [transactions])

  if (loading) {
    return (
      <div className="space-y-6">
        <div className="flex flex-wrap items-end gap-3">
          <SkeletonCard className="h-16 w-44" />
          <SkeletonCard className="h-16 w-44" />
          <SkeletonCard className="h-16 w-32" />
        </div>
        <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 xl:grid-cols-4">
          <SkeletonCard />
          <SkeletonCard />
          <SkeletonCard />
          <SkeletonCard />
        </div>
        <SkeletonCard className="h-80" />
        <SkeletonCard className="h-72" />
      </div>
    )
  }

  if (error) return <ErrorState message={error} onRetry={load} />

  const cards = [
    { icon: ReceiptText, bg: 'bg-primary/10 text-primary', label: `Transaksi (Rentang)`, value: formatAngka(transactions.length), sub: `${formatAngka(rangeSummary.items, 0)} item terjual` },
    { icon: Banknote, bg: 'bg-success/10 text-success', label: 'Omzet (Rentang)', value: formatRupiah(rangeSummary.omzet), sub: `${from} s/d ${to}` },
    { icon: BarChart3, bg: 'bg-warning/10 text-warning', label: `Omzet ${formatTanggalFromIso(daily?.date)}`, value: formatRupiah(daily?.summary.omzet ?? 0), sub: `${daily?.transactions ?? 0} transaksi` },
    { icon: TrendingUp, bg: 'bg-accentGreen/10 text-accentGreen', label: 'Omzet Bulan Ini', value: formatRupiah(monthly?.summary.omzet ?? 0), sub: `${monthly?.summary.total_transactions ?? 0} transaksi` },
  ]

  return (
    <div className="space-y-6">
      <Card className="flex flex-wrap items-end gap-3 p-5">
        <div className="flex items-center gap-2 pr-2">
          <CalendarRange size={18} className="text-primary" />
          <h2 className="text-sm font-bold text-textPrimary">Periode Laporan</h2>
        </div>
        <div>
          <label className="mb-1 block text-[11px] font-semibold text-textSecondary">Dari</label>
          <Input type="date" className="w-44" value={from} max={to} onChange={(e) => setFrom(e.target.value)} />
        </div>
        <div>
          <label className="mb-1 block text-[11px] font-semibold text-textSecondary">Sampai</label>
          <Input type="date" className="w-44" value={to} min={from} onChange={(e) => setTo(e.target.value)} />
        </div>
        <div className="ml-auto flex gap-2">
          <button
            onClick={() => handleExport('xlsx')}
            disabled={exporting === 'xlsx'}
            className="inline-flex items-center gap-2 rounded-lg border border-border bg-surface px-4 py-2 text-sm font-semibold text-textPrimary transition-colors hover:bg-background disabled:opacity-50"
          >
            {exporting === 'xlsx' ? (
              <span className="h-4 w-4 animate-spin rounded-full border-2 border-success border-t-transparent" />
            ) : (
              <FileSpreadsheet size={16} className="text-success" />
            )}
            Export Excel
          </button>
          <button
            onClick={() => handleExport('pdf')}
            disabled={exporting === 'pdf'}
            className="inline-flex items-center gap-2 rounded-lg border border-border bg-surface px-4 py-2 text-sm font-semibold text-textPrimary transition-colors hover:bg-background disabled:opacity-50"
          >
            {exporting === 'pdf' ? (
              <span className="h-4 w-4 animate-spin rounded-full border-2 border-danger border-t-transparent" />
            ) : (
              <FileText size={16} className="text-danger" />
            )}
            Export PDF
          </button>
        </div>
      </Card>

      <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 xl:grid-cols-4">
        {cards.map((c) => (
          <Card key={c.label} className="p-5">
            <div className="flex items-start gap-4">
              <div className={`rounded-xl p-3 ${c.bg}`}>
                <c.icon size={22} />
              </div>
              <div className="min-w-0">
                <p className="text-xs font-medium text-textSecondary">{c.label}</p>
                <p className="mt-1 truncate text-xl font-bold text-textPrimary">{c.value}</p>
                <p className="mt-0.5 truncate text-xs text-textSecondary">{c.sub}</p>
              </div>
            </div>
          </Card>
        ))}
      </div>

      <Card className="p-5">
        <div className="mb-4 flex items-center justify-between">
          <div>
            <h2 className="text-base font-bold text-textPrimary">Grafik Omzet Harian</h2>
            <p className="text-xs text-textSecondary">Agregasi transaksi dalam rentang {formatTanggalFromIso(from)} – {formatTanggalFromIso(to)}</p>
          </div>
          <Badge color="primary">{formatRupiah(rangeSummary.omzet)}</Badge>
        </div>
        {chartData.length === 0 ? (
          <EmptyState icon={BarChart3} message="Belum ada transaksi pada rentang ini" />
        ) : (
          <div className="h-80">
            <ResponsiveContainer width="100%" height="100%">
              <BarChart data={chartData} margin={{ top: 10, right: 10, left: 0, bottom: 0 }}>
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
                <Bar dataKey="omzet" fill="#0D6E6E" radius={[4, 4, 0, 0]} maxBarSize={36} />
              </BarChart>
            </ResponsiveContainer>
          </div>
        )}
      </Card>

      <Card className="overflow-hidden">
        <div className="border-b border-border px-5 py-4">
          <h2 className="text-base font-bold text-textPrimary">Daftar Transaksi</h2>
          <p className="text-xs text-textSecondary">Menampilkan maksimal 100 transaksi terbaru pada rentang</p>
        </div>
        {transactions.length === 0 ? (
          <EmptyState icon={Inbox} message="Tidak ada transaksi pada rentang ini" />
        ) : (
          <Table className="border-0">
            <Thead>
              <Th>Invoice</Th>
              <Th>Waktu</Th>
              <Th>Metode</Th>
              <Th className="text-right">Item</Th>
              <Th className="text-right">Total</Th>
              <Th>Status</Th>
            </Thead>
            <tbody>
              {transactions.map((t) => (
                <Tr key={t.id}>
                  <Td className="font-medium text-textPrimary">{t.invoice_no}</Td>
                  <Td className="text-textSecondary">{formatTanggalWaktu(t.created_at)}</Td>
                  <Td>
                    <Badge color={METHOD_COLORS[t.payment_method] ?? 'slate'}>{METHOD_LABELS[t.payment_method] ?? t.payment_method}</Badge>
                  </Td>
                  <Td className="text-right text-textSecondary">{t.items.reduce((a, i) => a + i.qty, 0)}</Td>
                  <Td className="text-right font-bold text-textPrimary">{formatRupiah(t.total_amount)}</Td>
                  <Td>{statusBadge(t.status)}</Td>
                </Tr>
              ))}
            </tbody>
          </Table>
        )}
      </Card>
    </div>
  )
}

function formatTanggalFromIso(iso?: string): string {
  if (!iso) return '-'
  const d = new Date(`${iso}T00:00:00`)
  return d.toLocaleDateString('id-ID', { day: 'numeric', month: 'short', year: 'numeric' })
}
