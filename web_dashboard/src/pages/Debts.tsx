import { useCallback, useEffect, useState } from 'react'
import {
  ChevronDown,
  ChevronUp,
  Phone,
  UserPlus,
  Users,
  Wallet,
} from 'lucide-react'
import { api, errMsg } from '../lib/api'
import { formatAngka, formatRupiah, formatTanggal, formatTanggalWaktu, parseDateLocal } from '../lib/format'
import type { CustomerDebt, DebtEntry } from '../lib/types'
import {
  Badge,
  Button,
  Card,
  EmptyState,
  ErrorState,
  Input,
  Modal,
  SkeletonCard,
  Spinner,
  cx,
} from '../components/ui'

function dueBadge(due: string | null) {
  if (!due) return <Badge color="slate">Tanpa jatuh tempo</Badge>
  const today = new Date()
  today.setHours(0, 0, 0, 0)
  const diff = Math.round((parseDateLocal(due).getTime() - today.getTime()) / 86400000)
  if (diff < 0) return <Badge color="red">Lewat {Math.abs(diff)} hari</Badge>
  if (diff === 0) return <Badge color="amber">Jatuh tempo hari ini</Badge>
  if (diff <= 7) return <Badge color="amber">{diff} hari lagi</Badge>
  return <Badge color="slate">Jatuh tempo {formatTanggal(due)}</Badge>
}

function statusBadge(status: string) {
  if (status === 'lunas') return <Badge color="green">Lunas</Badge>
  if (status === 'sebagian') return <Badge color="amber">Sebagian</Badge>
  return <Badge color="red">Belum Lunas</Badge>
}

export default function Debts() {
  const [debts, setDebts] = useState<CustomerDebt[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)
  const [openIds, setOpenIds] = useState<number[]>([])
  const [payTarget, setPayTarget] = useState<{ debt: DebtEntry; customerName: string } | null>(null)
  const [payAmount, setPayAmount] = useState('')
  const [payError, setPayError] = useState<string | null>(null)
  const [paying, setPaying] = useState(false)
  const [customerModal, setCustomerModal] = useState(false)
  const [custName, setCustName] = useState('')
  const [custPhone, setCustPhone] = useState('')
  const [custError, setCustError] = useState<string | null>(null)
  const [custSaving, setCustSaving] = useState(false)

  const load = useCallback(async () => {
    setLoading(true)
    setError(null)
    try {
      setDebts(await api<CustomerDebt[]>('/debts'))
    } catch (e) {
      setError(errMsg(e))
    } finally {
      setLoading(false)
    }
  }, [])

  useEffect(() => {
    load()
  }, [load])

  const toggle = (id: number) => {
    setOpenIds((ids) => (ids.includes(id) ? ids.filter((x) => x !== id) : [...ids, id]))
  }

  const openPay = (debt: DebtEntry, customerName: string) => {
    setPayTarget({ debt, customerName })
    setPayAmount(String(debt.remaining))
    setPayError(null)
  }

  const submitPay = async () => {
    const amount = toNum(payAmount)
    if (!payTarget) return
    if (!(amount > 0)) {
      setPayError('Nominal harus lebih dari 0')
      return
    }
    setPaying(true)
    setPayError(null)
    try {
      await api(`/debts/${payTarget.debt.id}/pay`, {
        method: 'POST',
        body: JSON.stringify({ amount_paid: amount }),
      })
      setPayTarget(null)
      await load()
    } catch (e) {
      setPayError(errMsg(e))
    } finally {
      setPaying(false)
    }
  }

  const submitCustomer = async () => {
    if (!custName.trim()) {
      setCustError('Nama pelanggan wajib diisi')
      return
    }
    setCustSaving(true)
    setCustError(null)
    try {
      await api('/customers', { method: 'POST', body: JSON.stringify({ name: custName.trim(), phone: custPhone.trim() || null }) })
      setCustomerModal(false)
      setCustName('')
      setCustPhone('')
    } catch (e) {
      setCustError(errMsg(e))
    } finally {
      setCustSaving(false)
    }
  }

  if (loading) {
    return (
      <div className="space-y-4">
        <SkeletonCard className="h-24" />
        <SkeletonCard className="h-24" />
        <SkeletonCard className="h-24" />
      </div>
    )
  }

  if (error) return <ErrorState message={error} onRetry={load} />

  return (
    <div className="space-y-4">
      <div className="flex items-center justify-between gap-3">
        <p className="text-sm text-textSecondary">
          {debts.length} pelanggan memiliki catatan utang
        </p>
        <Button onClick={() => setCustomerModal(true)}>
          <UserPlus size={16} /> Tambah Pelanggan
        </Button>
      </div>

      {debts.length === 0 ? (
        <Card>
          <EmptyState icon={Wallet} message="Belum ada data utang pelanggan" />
        </Card>
      ) : (
        debts.map((c) => {
          const remaining = Math.round((c.total_debt - c.total_paid) * 100) / 100
          const isOpen = openIds.includes(c.customer_id)
          return (
            <Card key={c.customer_id} className="overflow-hidden">
              <button onClick={() => toggle(c.customer_id)} className="flex w-full flex-wrap items-center justify-between gap-4 px-5 py-4 text-left transition-colors hover:bg-background/50">
                <div className="flex items-center gap-3">
                  <div className="rounded-full bg-accentGreen/10 p-3">
                    <Users size={20} className="text-accentGreen" />
                  </div>
                  <div>
                    <p className="font-bold text-textPrimary">{c.customer_name}</p>
                    <p className="flex items-center gap-1 text-xs text-textSecondary">
                      <Phone size={11} /> {c.phone || 'Tanpa telepon'}
                    </p>
                  </div>
                </div>
                <div className="flex flex-wrap items-center gap-x-8 gap-y-2">
                  <div>
                    <p className="text-[11px] text-textSecondary">Total Utang</p>
                    <p className="text-sm font-bold text-textPrimary">{formatRupiah(c.total_debt)}</p>
                  </div>
                  <div>
                    <p className="text-[11px] text-textSecondary">Total Bayar</p>
                    <p className="text-sm font-semibold text-success">{formatRupiah(c.total_paid)}</p>
                  </div>
                  <div>
                    <p className="text-[11px] text-textSecondary">Sisa</p>
                    <p className={cx('text-sm font-bold', remaining > 0 ? 'text-danger' : 'text-success')}>{formatRupiah(remaining)}</p>
                  </div>
                  {dueBadge(c.due_date_min)}
                  {isOpen ? <ChevronUp size={18} className="text-textSecondary" /> : <ChevronDown size={18} className="text-textSecondary" />}
                </div>
              </button>

              {isOpen && (
                <div className="space-y-3 border-t border-border bg-background/40 px-5 py-4">
                  <div className="h-2 w-full overflow-hidden rounded-full bg-border/60">
                    <div
                      className="h-full rounded-full bg-success transition-all"
                      style={{ width: `${c.total_debt > 0 ? Math.min(100, (c.total_paid / c.total_debt) * 100) : 100}%` }}
                    />
                  </div>
                  <div className="flex justify-between text-[11px] text-textSecondary">
                    <span>{c.debts.length} tagihan</span>
                    <span>{formatAngka(c.total_debt > 0 ? (c.total_paid / c.total_debt) * 100 : 100, 0)}% terbayar</span>
                  </div>

                  <div className="space-y-2">
                    {c.debts.map((d) => (
                      <div key={d.id} className="flex flex-wrap items-center justify-between gap-3 rounded-lg border border-border bg-surface px-4 py-3">
                        <div>
                          <p className="text-sm font-medium text-textPrimary">
                            Tagihan #{d.id} <span className="text-textSecondary">· {formatTanggalWaktu(d.created_at)}</span>
                          </p>
                          <div className="mt-1 flex flex-wrap items-center gap-2">
                            {statusBadge(d.status)}
                            {dueBadge(d.due_date)}
                          </div>
                        </div>
                        <div className="flex flex-wrap items-center gap-6">
                          <div className="text-right">
                            <p className="text-[11px] text-textSecondary">Total</p>
                            <p className="text-sm font-semibold text-textPrimary">{formatRupiah(d.amount)}</p>
                          </div>
                          <div className="text-right">
                            <p className="text-[11px] text-textSecondary">Sisa</p>
                            <p className="text-sm font-semibold text-textPrimary">{formatRupiah(d.remaining)}</p>
                          </div>
                          <Button
                            variant="primary"
                            size="sm"
                            disabled={d.remaining <= 0}
                            onClick={() => openPay(d, c.customer_name)}
                          >
                            <Wallet size={14} /> Bayar
                          </Button>
                        </div>
                      </div>
                    ))}
                  </div>
                </div>
              )}
            </Card>
          )
        })
      )}

      <Modal
        open={payTarget !== null}
        title={payTarget ? `Pembayaran Utang — ${payTarget.customerName}` : 'Pembayaran Utang'}
        onClose={() => setPayTarget(null)}
        footer={
          <>
            <Button variant="secondary" onClick={() => setPayTarget(null)}>Batal</Button>
            <Button onClick={submitPay} disabled={paying}>
              {paying && <Spinner size={14} className="text-white" />}
              Konfirmasi Pembayaran
            </Button>
          </>
        }
      >
        <div className="space-y-4">
          {payError && (
            <div className="rounded-lg border border-danger/30 bg-danger/5 px-3 py-2 text-xs font-medium text-danger">{payError}</div>
          )}
          {payTarget && (
            <div className="grid grid-cols-2 gap-3">
              <div className="rounded-lg border border-border bg-background/60 px-4 py-3">
                <p className="text-[11px] text-textSecondary">Total Tagihan</p>
                <p className="text-base font-bold text-textPrimary">{formatRupiah(payTarget.debt.amount)}</p>
              </div>
              <div className="rounded-lg border border-border bg-background/60 px-4 py-3">
                <p className="text-[11px] text-textSecondary">Sisa Utang</p>
                <p className="text-base font-bold text-danger">{formatRupiah(payTarget.debt.remaining)}</p>
              </div>
            </div>
          )}
          <div>
            <label className="mb-1 block text-xs font-semibold text-textSecondary">Nominal Pembayaran</label>
            <Input
              type="number"
              min="0"
              step="any"
              value={payAmount}
              onChange={(e) => setPayAmount(e.target.value)}
              autoFocus
            />
          </div>
        </div>
      </Modal>

      <Modal
        open={customerModal}
        title="Tambah Pelanggan"
        onClose={() => setCustomerModal(false)}
        footer={
          <>
            <Button variant="secondary" onClick={() => setCustomerModal(false)}>Batal</Button>
            <Button onClick={submitCustomer} disabled={custSaving}>
              {custSaving && <Spinner size={14} className="text-white" />}
              Simpan
            </Button>
          </>
        }
      >
        <div className="space-y-4">
          {custError && (
            <div className="rounded-lg border border-danger/30 bg-danger/5 px-3 py-2 text-xs font-medium text-danger">{custError}</div>
          )}
          <div>
            <label className="mb-1 block text-xs font-semibold text-textSecondary">Nama Pelanggan *</label>
            <Input value={custName} onChange={(e) => setCustName(e.target.value)} placeholder="mis. Bu Sari" autoFocus />
          </div>
          <div>
            <label className="mb-1 block text-xs font-semibold text-textSecondary">No. Telepon</label>
            <Input value={custPhone} onChange={(e) => setCustPhone(e.target.value)} placeholder="Opsional" />
          </div>
        </div>
      </Modal>
    </div>
  )
}

const toNum = (s: string): number => {
  const n = parseFloat(s)
  return Number.isFinite(n) ? n : 0
}
