import { useCallback, useEffect, useState } from 'react'
import { History, PackageCheck, PackageX, SlidersHorizontal } from 'lucide-react'
import { api, errMsg } from '../lib/api'
import { formatAngka, formatTanggalWaktu } from '../lib/format'
import type { StockAlert, StockLogItem } from '../lib/types'
import {
  Badge,
  Button,
  Card,
  EmptyState,
  ErrorState,
  Input,
  Modal,
  SkeletonRow,
  Spinner,
  Table,
  Td,
  Th,
  Thead,
  Tr,
} from '../components/ui'

const toNum = (s: string): number => {
  const n = parseFloat(s)
  return Number.isFinite(n) ? n : 0
}

export default function Stock() {
  const [alerts, setAlerts] = useState<StockAlert[]>([])
  const [logs, setLogs] = useState<StockLogItem[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)
  const [adjTarget, setAdjTarget] = useState<StockAlert | null>(null)
  const [adjQty, setAdjQty] = useState('')
  const [adjReason, setAdjReason] = useState('')
  const [adjError, setAdjError] = useState<string | null>(null)
  const [adjusting, setAdjusting] = useState(false)

  const load = useCallback(async () => {
    setLoading(true)
    setError(null)
    try {
      const [alertList, logList] = await Promise.all([
        api<StockAlert[]>('/stock/alerts'),
        api<StockLogItem[]>('/stock/logs?limit=100'),
      ])
      setAlerts(alertList)
      setLogs(logList)
    } catch (e) {
      setError(errMsg(e))
    } finally {
      setLoading(false)
    }
  }, [])

  useEffect(() => {
    load()
  }, [load])

  const openAdjust = (a: StockAlert) => {
    setAdjTarget(a)
    setAdjQty('')
    setAdjReason('')
    setAdjError(null)
  }

  const submitAdjust = async () => {
    const qty = toNum(adjQty)
    if (!adjReason.trim()) {
      setAdjError('Alasan wajib diisi')
      return
    }
    if (qty === 0) {
      setAdjError('Jumlah perubahan tidak boleh 0')
      return
    }
    if (!adjTarget) return
    if (qty < 0 && Math.abs(qty) > adjTarget.stock) {
      setAdjError(`Pengurangan melebihi stok saat ini (${formatAngka(adjTarget.stock, 2)})`)
      return
    }
    setAdjusting(true)
    setAdjError(null)
    try {
      await api('/stock/adjust', {
        method: 'POST',
        body: JSON.stringify({ product_id: adjTarget.id, change_qty: qty, reason: adjReason.trim() }),
      })
      setAdjTarget(null)
      await load()
    } catch (e) {
      setAdjError(errMsg(e))
    } finally {
      setAdjusting(false)
    }
  }

  if (loading) {
    return (
      <div className="space-y-6">
        <Card className="overflow-hidden">
          <div className="border-b border-border px-5 py-4">
            <div className="h-4 w-40 animate-pulse rounded-md bg-slate-200/70" />
          </div>
          <Table className="border-0">
            <Thead>
              <Th>Produk</Th>
              <Th>SKU</Th>
              <Th className="text-right">Stok</Th>
              <Th className="text-right">Ambang</Th>
              <Th>Status</Th>
              <Th className="text-right">Aksi</Th>
            </Thead>
            <tbody>
              <SkeletonRow cols={6} />
              <SkeletonRow cols={6} />
              <SkeletonRow cols={6} />
            </tbody>
          </Table>
        </Card>
        <Card className="overflow-hidden">
          <div className="border-b border-border px-5 py-4">
            <div className="h-4 w-40 animate-pulse rounded-md bg-slate-200/70" />
          </div>
          <Table className="border-0">
            <Thead>
              <Th>Waktu</Th>
              <Th>Produk</Th>
              <Th className="text-right">Perubahan</Th>
              <Th>Alasan</Th>
            </Thead>
            <tbody>
              <SkeletonRow cols={4} />
              <SkeletonRow cols={4} />
              <SkeletonRow cols={4} />
              <SkeletonRow cols={4} />
            </tbody>
          </Table>
        </Card>
      </div>
    )
  }

  if (error) return <ErrorState message={error} onRetry={load} />

  return (
    <div className="space-y-6">
      <Card className="overflow-hidden">
        <div className="flex items-center justify-between gap-3 border-b border-border px-5 py-4">
          <div className="flex items-center gap-2">
            <PackageX size={18} className="text-danger" />
            <h2 className="text-base font-bold text-textPrimary">Alert Stok Menipis & Habis</h2>
          </div>
          <Badge color={alerts.length > 0 ? 'red' : 'green'}>{alerts.length} produk</Badge>
        </div>
        {alerts.length === 0 ? (
          <EmptyState icon={PackageCheck} message="Semua stok dalam kondisi aman" />
        ) : (
          <Table className="border-0">
            <Thead>
              <Th>Produk</Th>
              <Th>SKU</Th>
              <Th className="text-right">Stok Saat Ini</Th>
              <Th className="text-right">Ambang Alert</Th>
              <Th>Status</Th>
              <Th className="text-right">Aksi</Th>
            </Thead>
            <tbody>
              {alerts.map((a) => (
                <Tr key={a.id}>
                  <Td>
                    <p className="font-medium text-textPrimary">{a.name}</p>
                  </Td>
                  <Td className="text-textSecondary">{a.sku ?? '-'}</Td>
                  <Td className="text-right font-bold text-textPrimary">{formatAngka(a.stock, 2)}</Td>
                  <Td className="text-right text-textSecondary">{formatAngka(a.stock_alert_threshold, 0)}</Td>
                  <Td>
                    <Badge color={a.status === 'habis' ? 'red' : 'amber'}>{a.status === 'habis' ? 'Habis' : 'Menipis'}</Badge>
                  </Td>
                  <Td className="text-right">
                    <Button variant="secondary" size="sm" onClick={() => openAdjust(a)}>
                      <SlidersHorizontal size={14} /> Koreksi Stok
                    </Button>
                  </Td>
                </Tr>
              ))}
            </tbody>
          </Table>
        )}
      </Card>

      <Card className="overflow-hidden">
        <div className="flex items-center gap-2 border-b border-border px-5 py-4">
          <History size={18} className="text-primary" />
          <h2 className="text-base font-bold text-textPrimary">Riwayat Perubahan Stok</h2>
        </div>
        {logs.length === 0 ? (
          <EmptyState icon={History} message="Belum ada riwayat perubahan stok" />
        ) : (
          <Table className="border-0">
            <Thead>
              <Th>Waktu</Th>
              <Th>Produk</Th>
              <Th className="text-right">Perubahan</Th>
              <Th>Alasan</Th>
            </Thead>
            <tbody>
              {logs.map((log) => (
                <Tr key={log.id}>
                  <Td className="text-textSecondary">{formatTanggalWaktu(log.created_at)}</Td>
                  <Td className="font-medium text-textPrimary">{log.product_name}</Td>
                  <Td className="text-right">
                    <span className={`inline-flex items-center gap-1 font-bold ${log.change_qty >= 0 ? 'text-success' : 'text-danger'}`}>
                      {log.change_qty >= 0 ? `+${formatAngka(log.change_qty, 2)}` : formatAngka(log.change_qty, 2)}
                    </span>
                  </Td>
                  <Td className="text-textSecondary">{log.reason || '-'}</Td>
                </Tr>
              ))}
            </tbody>
          </Table>
        )}
      </Card>

      <Modal
        open={adjTarget !== null}
        title={adjTarget ? `Koreksi Stok — ${adjTarget.name}` : 'Koreksi Stok'}
        onClose={() => setAdjTarget(null)}
        footer={
          <>
            <Button variant="secondary" onClick={() => setAdjTarget(null)}>Batal</Button>
            <Button onClick={submitAdjust} disabled={adjusting}>
              {adjusting && <Spinner size={14} className="text-white" />}
              Simpan Koreksi
            </Button>
          </>
        }
      >
        <div className="space-y-4">
          {adjError && (
            <div className="rounded-lg border border-danger/30 bg-danger/5 px-3 py-2 text-xs font-medium text-danger">{adjError}</div>
          )}
          {adjTarget && (
            <div className="rounded-lg border border-border bg-background/60 px-4 py-3 text-sm">
              Stok saat ini: <span className="font-bold text-textPrimary">{formatAngka(adjTarget.stock, 2)}</span> dari ambang{' '}
              {formatAngka(adjTarget.stock_alert_threshold, 0)}
            </div>
          )}
          <div>
            <label className="mb-1 block text-xs font-semibold text-textSecondary">Jumlah Perubahan (+/−)</label>
            <Input
              type="number"
              step="any"
              value={adjQty}
              onChange={(e) => setAdjQty(e.target.value)}
              placeholder="mis. 10 (tambah) atau -3 (kurang)"
              autoFocus
            />
          </div>
          <div>
            <label className="mb-1 block text-xs font-semibold text-textSecondary">Alasan *</label>
            <Input value={adjReason} onChange={(e) => setAdjReason(e.target.value)} placeholder="mis. barang datang, stok fisik, retur" />
          </div>
        </div>
      </Modal>
    </div>
  )
}
