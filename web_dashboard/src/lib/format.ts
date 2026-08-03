const rupiahNoDecimal = new Intl.NumberFormat('id-ID', {
  style: 'currency',
  currency: 'IDR',
  maximumFractionDigits: 0,
})

const rupiahDecimal = new Intl.NumberFormat('id-ID', {
  style: 'currency',
  currency: 'IDR',
  minimumFractionDigits: 0,
  maximumFractionDigits: 2,
})

export function formatRupiah(value: number | null | undefined): string {
  if (value === null || value === undefined || Number.isNaN(value)) return '-'
  if (Math.abs(value) >= 10000) return rupiahNoDecimal.format(value)
  return rupiahDecimal.format(value)
}

export function formatRupiahCompact(value: number | null | undefined): string {
  if (value === null || value === undefined || Number.isNaN(value)) return '-'
  const v = Number(value)
  if (Math.abs(v) >= 1_000_000) {
    return `Rp ${(v / 1_000_000).toLocaleString('id-ID', { maximumFractionDigits: 1 })} jt`
  }
  if (Math.abs(v) >= 1_000) {
    return `Rp ${Math.round(v / 1000)} rb`
  }
  return `Rp ${Math.round(v)}`
}

export function formatAngka(value: number | null | undefined, digits = 0): string {
  if (value === null || value === undefined || Number.isNaN(value)) return '-'
  return new Intl.NumberFormat('id-ID', { maximumFractionDigits: digits }).format(value)
}

export function formatTanggal(iso: string | null | undefined): string {
  if (!iso) return '-'
  const d = new Date(iso)
  if (Number.isNaN(d.getTime())) return '-'
  return d.toLocaleDateString('id-ID', { day: 'numeric', month: 'short', year: 'numeric' })
}

export function formatWaktu(iso: string | null | undefined): string {
  if (!iso) return '-'
  const d = new Date(iso)
  if (Number.isNaN(d.getTime())) return '-'
  return d.toLocaleTimeString('id-ID', { hour: '2-digit', minute: '2-digit' })
}

export function formatTanggalWaktu(iso: string | null | undefined): string {
  if (!iso) return '-'
  return `${formatTanggal(iso)} ${formatWaktu(iso)}`
}

export function parseDateLocal(s: string): Date {
  return new Date(Number(s.slice(0, 4)), Number(s.slice(5, 7)) - 1, Number(s.slice(8, 10)))
}
