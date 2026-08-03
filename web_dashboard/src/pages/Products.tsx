import { useCallback, useEffect, useState } from 'react'
import {
  FolderPlus,
  Inbox,
  Package,
  Pencil,
  Plus,
  Search,
  Star,
  Trash2,
} from 'lucide-react'
import { api, errMsg } from '../lib/api'
import { formatRupiah } from '../lib/format'
import type { Category, Product, ProductListResponse } from '../lib/types'
import {
  Badge,
  Button,
  Card,
  EmptyState,
  ErrorState,
  Input,
  Modal,
  PaginationBar,
  Select,
  SkeletonRow,
  Spinner,
  Table,
  Td,
  Th,
  Thead,
  Tr,
} from '../components/ui'

const PAGE_SIZE = 50

interface UnitRow {
  unit_name: string
  conversion_qty: string
  price_sell: string
}

interface ProductForm {
  name: string
  category_id: string
  barcode: string
  sku: string
  unit_base: string
  price_buy: string
  price_sell: string
  stock: string
  stock_alert_threshold: string
  is_favorite: boolean
  units: UnitRow[]
}

const EMPTY_FORM: ProductForm = {
  name: '',
  category_id: '',
  barcode: '',
  sku: '',
  unit_base: 'pcs',
  price_buy: '',
  price_sell: '',
  stock: '',
  stock_alert_threshold: '5',
  is_favorite: false,
  units: [],
}

const toNum = (s: string): number => {
  const n = parseFloat(s)
  return Number.isFinite(n) ? n : 0
}

const productPayload = (p: Product, overrides: Partial<Record<string, unknown>> = {}) => ({
  name: p.name,
  category_id: p.category_id,
  barcode: p.barcode,
  sku: p.sku,
  photo_path: p.photo_path,
  unit_base: p.unit_base,
  price_buy: p.price_buy,
  price_sell: p.price_sell,
  stock: p.stock,
  stock_alert_threshold: p.stock_alert_threshold,
  is_favorite: p.is_favorite,
  is_active: p.is_active,
  units: p.units.map((u) => ({ unit_name: u.unit_name, conversion_qty: u.conversion_qty, price_sell: u.price_sell })),
  ...overrides,
})

function stockBadge(stock: number, threshold: number) {
  if (stock <= 0) return <Badge color="red">Habis</Badge>
  if (stock <= threshold) return <Badge color="amber">Menipis</Badge>
  return <Badge color="green">Cukup</Badge>
}

export default function Products() {
  const [products, setProducts] = useState<Product[]>([])
  const [categories, setCategories] = useState<Category[]>([])
  const [total, setTotal] = useState(0)
  const [page, setPage] = useState(1)
  const [search, setSearch] = useState('')
  const [searching, setSearching] = useState(false)
  const [searchResult, setSearchResult] = useState<Product[] | null>(null)
  const [categoryId, setCategoryId] = useState('')
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)
  const [modalOpen, setModalOpen] = useState(false)
  const [editing, setEditing] = useState<Product | null>(null)
  const [form, setForm] = useState<ProductForm>(EMPTY_FORM)
  const [formError, setFormError] = useState<string | null>(null)
  const [saving, setSaving] = useState(false)
  const [catModalOpen, setCatModalOpen] = useState(false)
  const [catName, setCatName] = useState('')
  const [catSaving, setCatSaving] = useState(false)
  const [catError, setCatError] = useState<string | null>(null)

  const load = useCallback(async () => {
    setLoading(true)
    setError(null)
    try {
      const params = new URLSearchParams({ page: String(page), page_size: String(PAGE_SIZE), include_inactive: 'true' })
      if (categoryId) params.set('category_id', categoryId)
      const res = await api<ProductListResponse>(`/products?${params.toString()}`)
      setProducts(res.items)
      setTotal(res.total)
    } catch (e) {
      setError(errMsg(e))
    } finally {
      setLoading(false)
    }
  }, [page, categoryId])

  const loadCategories = useCallback(async () => {
    try {
      setCategories(await api<Category[]>('/categories'))
    } catch {
      // kategori opsional
    }
  }, [])

  const runSearch = useCallback(async (q: string) => {
    setSearching(true)
    setError(null)
    try {
      setSearchResult(await api<Product[]>(`/products/search?q=${encodeURIComponent(q)}`))
    } catch (e) {
      setError(errMsg(e))
    } finally {
      setSearching(false)
    }
  }, [])

  useEffect(() => {
    load()
  }, [load])

  useEffect(() => {
    loadCategories()
  }, [loadCategories])

  useEffect(() => {
    const trimmed = search.trim()
    if (!trimmed) {
      setSearchResult(null)
      return
    }
    const timer = setTimeout(() => runSearch(trimmed), 350)
    return () => clearTimeout(timer)
  }, [search, runSearch])

  const openCreate = () => {
    setEditing(null)
    setForm(EMPTY_FORM)
    setFormError(null)
    setModalOpen(true)
  }

  const openEdit = (p: Product) => {
    setEditing(p)
    setForm({
      name: p.name,
      category_id: p.category_id ? String(p.category_id) : '',
      barcode: p.barcode ?? '',
      sku: p.sku ?? '',
      unit_base: p.unit_base,
      price_buy: String(p.price_buy),
      price_sell: String(p.price_sell),
      stock: String(p.stock),
      stock_alert_threshold: String(p.stock_alert_threshold),
      is_favorite: p.is_favorite,
      units: p.units.map((u) => ({ unit_name: u.unit_name, conversion_qty: String(u.conversion_qty), price_sell: String(u.price_sell) })),
    })
    setFormError(null)
    setModalOpen(true)
  }

  const setField = (key: keyof ProductForm, value: string | boolean) => {
    setForm((f) => ({ ...f, [key]: value }))
  }

  const updateUnit = (index: number, key: keyof UnitRow, value: string) => {
    setForm((f) => ({
      ...f,
      units: f.units.map((u, i) => (i === index ? { ...u, [key]: value } : u)),
    }))
  }

  const addUnit = () => {
    setForm((f) => ({ ...f, units: [...f.units, { unit_name: '', conversion_qty: '', price_sell: '' }] }))
  }

  const removeUnit = (index: number) => {
    setForm((f) => ({ ...f, units: f.units.filter((_, i) => i !== index) }))
  }

  const submit = async () => {
    const errs: string[] = []
    if (!form.name.trim()) errs.push('Nama produk wajib diisi')
    if (!(toNum(form.price_sell) > 0)) errs.push('Harga jual harus lebih dari 0')
    if (errs.length > 0) {
      setFormError(errs.join(' · '))
      return
    }
    setSaving(true)
    setFormError(null)
    try {
      const payload = {
        name: form.name.trim(),
        category_id: form.category_id ? Number(form.category_id) : null,
        barcode: form.barcode.trim() || null,
        sku: form.sku.trim() || null,
        photo_path: editing?.photo_path ?? null,
        unit_base: form.unit_base.trim() || 'pcs',
        price_buy: toNum(form.price_buy),
        price_sell: toNum(form.price_sell),
        stock: toNum(form.stock),
        stock_alert_threshold: toNum(form.stock_alert_threshold),
        is_favorite: form.is_favorite,
        is_active: editing ? editing.is_active : true,
        units: form.units
          .filter((u) => u.unit_name.trim() !== '' && toNum(u.conversion_qty) > 0 && toNum(u.price_sell) > 0)
          .map((u) => ({ unit_name: u.unit_name.trim(), conversion_qty: toNum(u.conversion_qty), price_sell: toNum(u.price_sell) })),
      }
      if (editing) {
        await api(`/products/${editing.id}`, { method: 'PUT', body: JSON.stringify(payload) })
      } else {
        await api('/products', { method: 'POST', body: JSON.stringify(payload) })
      }
      setModalOpen(false)
      await load()
    } catch (e) {
      setFormError(errMsg(e))
    } finally {
      setSaving(false)
    }
  }

  const toggleField = async (p: Product, field: 'is_active' | 'is_favorite') => {
    try {
      await api(`/products/${p.id}`, {
        method: 'PUT',
        body: JSON.stringify(productPayload(p, { [field]: !p[field] })),
      })
      await load()
    } catch (e) {
      setError(errMsg(e))
    }
  }

  const deactivate = async (p: Product) => {
    if (!window.confirm(`Nonaktifkan produk "${p.name}"? Produk tetap tersimpan di database.`)) return
    try {
      await api(`/products/${p.id}`, { method: 'DELETE' })
      await load()
    } catch (e) {
      setError(errMsg(e))
    }
  }

  const submitCategory = async () => {
    if (!catName.trim()) {
      setCatError('Nama kategori wajib diisi')
      return
    }
    setCatSaving(true)
    setCatError(null)
    try {
      await api('/categories', { method: 'POST', body: JSON.stringify({ name: catName.trim() }) })
      setCatModalOpen(false)
      setCatName('')
      await loadCategories()
    } catch (e) {
      setCatError(errMsg(e))
    } finally {
      setCatSaving(false)
    }
  }

  const showRows = searchResult ?? products
  const isSearching = searchResult !== null

  if (loading && !isSearching) {
    return (
      <div className="space-y-4">
        <Card className="p-4">
          <div className="h-10 animate-pulse rounded-lg bg-slate-200/70" />
        </Card>
        <Card className="overflow-hidden">
          <Table className="border-0">
            <Thead>
              <Th>Produk</Th>
              <Th>Kategori</Th>
              <Th>Satuan</Th>
              <Th className="text-right">Harga Beli</Th>
              <Th className="text-right">Harga Jual</Th>
              <Th className="text-right">Stok</Th>
              <Th>Status</Th>
              <Th>Favorit</Th>
              <Th className="text-right">Aksi</Th>
            </Thead>
            <tbody>
              <SkeletonRow cols={9} />
              <SkeletonRow cols={9} />
              <SkeletonRow cols={9} />
              <SkeletonRow cols={9} />
              <SkeletonRow cols={9} />
            </tbody>
          </Table>
        </Card>
      </div>
    )
  }

  if (error) return <ErrorState message={error} onRetry={load} />

  return (
    <div className="space-y-4">
      <div className="flex flex-wrap items-center justify-between gap-3">
        <div className="flex flex-1 flex-wrap items-center gap-2">
          <div className="relative min-w-[220px] flex-1 sm:max-w-xs">
            <Search size={16} className="pointer-events-none absolute left-3 top-1/2 -translate-y-1/2 text-textSecondary" />
            <Input className="pl-9" placeholder="Cari produk..." value={search} onChange={(e) => setSearch(e.target.value)} />
          </div>
          <Select className="w-44" value={categoryId} onChange={(e) => { setCategoryId(e.target.value); setPage(1) }}>
            <option value="">Semua Kategori</option>
            {categories.map((c) => (
              <option key={c.id} value={c.id}>{c.name}</option>
            ))}
          </Select>
          <Button variant="secondary" size="sm" onClick={() => setCatModalOpen(true)}>
            <FolderPlus size={14} /> Kategori
          </Button>
        </div>
        <Button onClick={openCreate}>
          <Plus size={16} /> Tambah Produk
        </Button>
      </div>

      {isSearching && (
        <p className="text-xs text-textSecondary">
          Hasil pencarian untuk "{search.trim()}" — {showRows.length} produk ditemukan
        </p>
      )}

      <Card className="overflow-hidden">
        <Table className="border-0">
          <Thead>
            <Th>Produk</Th>
            <Th>Kategori</Th>
            <Th>Satuan</Th>
            <Th className="text-right">Harga Beli</Th>
            <Th className="text-right">Harga Jual</Th>
            <Th className="text-right">Stok</Th>
            <Th>Status</Th>
            <Th>Favorit</Th>
            <Th className="text-right">Aksi</Th>
          </Thead>
          <tbody>
            {searching ? (
              <>
                <SkeletonRow cols={9} />
                <SkeletonRow cols={9} />
              </>
            ) : showRows.length === 0 ? (
              <tr>
                <td colSpan={9}>
                  <EmptyState icon={Inbox} message="Tidak ada produk ditemukan" />
                </td>
              </tr>
            ) : (
              showRows.map((p) => (
                <Tr key={p.id} onClick={() => openEdit(p)}>
                  <Td>
                    <div className="flex items-center gap-3">
                      <div className="flex h-10 w-10 shrink-0 items-center justify-center rounded-lg border border-border bg-background">
                        <Package size={18} className="text-textSecondary" />
                      </div>
                      <div className="min-w-0">
                        <p className="max-w-[220px] truncate font-medium text-textPrimary">{p.name}</p>
                        <p className="text-[11px] text-textSecondary">{p.sku ?? '-'}</p>
                      </div>
                    </div>
                  </Td>
                  <Td className="text-textSecondary">{p.category_name ?? '-'}</Td>
                  <Td className="text-textSecondary">{p.unit_base}</Td>
                  <Td className="text-right text-textSecondary">{formatRupiah(p.price_buy)}</Td>
                  <Td className="text-right font-semibold text-textPrimary">{formatRupiah(p.price_sell)}</Td>
                  <Td className="text-right">{stockBadge(p.stock, p.stock_alert_threshold)}</Td>
                  <Td>
                    <button
                      onClick={(e) => { e.stopPropagation(); toggleField(p, 'is_active') }}
                      className={`relative h-6 w-11 rounded-full transition-colors ${p.is_active ? 'bg-success' : 'bg-slate-300'}`}
                      title={p.is_active ? 'Aktif — klik untuk nonaktifkan' : 'Nonaktif — klik untuk aktifkan'}
                    >
                      <span className={`absolute top-0.5 h-5 w-5 rounded-full bg-white shadow transition-all ${p.is_active ? 'left-[22px]' : 'left-0.5'}`} />
                    </button>
                  </Td>
                  <Td>
                    <button
                      onClick={(e) => { e.stopPropagation(); toggleField(p, 'is_favorite') }}
                      className="rounded-lg p-1.5 transition-colors hover:bg-background"
                      title={p.is_favorite ? 'Hapus dari favorit' : 'Tandai favorit'}
                    >
                      <Star size={18} className={p.is_favorite ? 'fill-warning text-warning' : 'text-textSecondary'} />
                    </button>
                  </Td>
                  <Td className="text-right">
                    <div className="flex justify-end gap-1">
                      <button
                        onClick={(e) => { e.stopPropagation(); openEdit(p) }}
                        className="rounded-lg p-1.5 text-textSecondary transition-colors hover:bg-background hover:text-primary"
                        title="Edit produk"
                      >
                        <Pencil size={16} />
                      </button>
                      <button
                        onClick={(e) => { e.stopPropagation(); deactivate(p) }}
                        className="rounded-lg p-1.5 text-textSecondary transition-colors hover:bg-background hover:text-danger"
                        title="Nonaktifkan"
                      >
                        <Trash2 size={16} />
                      </button>
                    </div>
                  </Td>
                </Tr>
              ))
            )}
          </tbody>
        </Table>
      </Card>

      {!isSearching && (
        <PaginationBar page={page} pageSize={PAGE_SIZE} total={total} onPage={(p) => { setPage(p); window.scrollTo({ top: 0 }) }} />
      )}

      <Modal
        open={modalOpen}
        title={editing ? `Edit Produk — ${editing.name}` : 'Tambah Produk'}
        onClose={() => setModalOpen(false)}
        wide
        footer={
          <>
            <Button variant="secondary" onClick={() => setModalOpen(false)}>Batal</Button>
            <Button onClick={submit} disabled={saving}>
              {saving && <Spinner size={14} className="text-white" />}
              {editing ? 'Simpan Perubahan' : 'Simpan Produk'}
            </Button>
          </>
        }
      >
        <div className="space-y-4">
          {formError && (
            <div className="rounded-lg border border-danger/30 bg-danger/5 px-3 py-2 text-xs font-medium text-danger">{formError}</div>
          )}
          <div className="grid grid-cols-1 gap-4 sm:grid-cols-2">
            <div className="sm:col-span-2">
              <label className="mb-1 block text-xs font-semibold text-textSecondary">Nama Produk *</label>
              <Input value={form.name} onChange={(e) => setField('name', e.target.value)} placeholder="Mis. Indomie Goreng" />
            </div>
            <div>
              <label className="mb-1 block text-xs font-semibold text-textSecondary">Kategori</label>
              <div className="flex gap-2">
                <Select value={form.category_id} onChange={(e) => setField('category_id', e.target.value)}>
                  <option value="">Tanpa kategori</option>
                  {categories.map((c) => (
                    <option key={c.id} value={c.id}>{c.name}</option>
                  ))}
                </Select>
                <Button variant="secondary" size="sm" className="shrink-0" onClick={() => setCatModalOpen(true)} title="Tambah kategori">
                  <FolderPlus size={14} />
                </Button>
              </div>
            </div>
            <div>
              <label className="mb-1 block text-xs font-semibold text-textSecondary">Satuan Dasar</label>
              <Input value={form.unit_base} onChange={(e) => setField('unit_base', e.target.value)} placeholder="pcs" />
            </div>
            <div>
              <label className="mb-1 block text-xs font-semibold text-textSecondary">Barcode</label>
              <Input value={form.barcode} onChange={(e) => setField('barcode', e.target.value)} placeholder="Opsional" />
            </div>
            <div>
              <label className="mb-1 block text-xs font-semibold text-textSecondary">SKU</label>
              <Input value={form.sku} onChange={(e) => setField('sku', e.target.value)} placeholder="Kosongkan untuk otomatis" />
            </div>
            <div>
              <label className="mb-1 block text-xs font-semibold text-textSecondary">Harga Beli</label>
              <Input type="number" min="0" step="any" value={form.price_buy} onChange={(e) => setField('price_buy', e.target.value)} placeholder="0" />
            </div>
            <div>
              <label className="mb-1 block text-xs font-semibold text-textSecondary">Harga Jual *</label>
              <Input type="number" min="0" step="any" value={form.price_sell} onChange={(e) => setField('price_sell', e.target.value)} placeholder="0" />
            </div>
            <div>
              <label className="mb-1 block text-xs font-semibold text-textSecondary">Stok Awal</label>
              <Input type="number" min="0" step="any" value={form.stock} onChange={(e) => setField('stock', e.target.value)} placeholder="0" />
            </div>
            <div>
              <label className="mb-1 block text-xs font-semibold text-textSecondary">Ambang Batas Alert</label>
              <Input type="number" min="0" step="any" value={form.stock_alert_threshold} onChange={(e) => setField('stock_alert_threshold', e.target.value)} placeholder="5" />
            </div>
          </div>

          <label className="flex items-center gap-2 text-sm text-textPrimary">
            <input
              type="checkbox"
              checked={form.is_favorite}
              onChange={(e) => setField('is_favorite', e.target.checked)}
              className="h-4 w-4 accent-[#0D6E6E]"
            />
            Tandai sebagai produk favorit
          </label>

          <div className="rounded-xl border border-border bg-background/50 p-4">
            <div className="mb-3 flex items-center justify-between">
              <p className="text-sm font-bold text-textPrimary">Satuan Tambahan</p>
              <Button variant="secondary" size="sm" onClick={addUnit}>
                <Plus size={14} /> Tambah Satuan
              </Button>
            </div>
            {form.units.length === 0 && <p className="text-xs text-textSecondary">Belum ada satuan tambahan.</p>}
            <div className="space-y-2">
              {form.units.map((u, i) => (
                <div key={i} className="grid grid-cols-1 items-end gap-2 sm:grid-cols-[1fr_100px_120px_40px]">
                  <div>
                    <label className="mb-1 block text-[11px] font-semibold text-textSecondary">Nama Satuan</label>
                    <Input placeholder="mis. dus" value={u.unit_name} onChange={(e) => updateUnit(i, 'unit_name', e.target.value)} />
                  </div>
                  <div>
                    <label className="mb-1 block text-[11px] font-semibold text-textSecondary">Konversi</label>
                    <Input type="number" min="0" step="any" placeholder="mis. 12" value={u.conversion_qty} onChange={(e) => updateUnit(i, 'conversion_qty', e.target.value)} />
                  </div>
                  <div>
                    <label className="mb-1 block text-[11px] font-semibold text-textSecondary">Harga Jual</label>
                    <Input type="number" min="0" step="any" placeholder="0" value={u.price_sell} onChange={(e) => updateUnit(i, 'price_sell', e.target.value)} />
                  </div>
                  <Button variant="ghost" size="sm" onClick={() => removeUnit(i)} title="Hapus satuan">
                    <Trash2 size={16} className="text-danger" />
                  </Button>
                </div>
              ))}
            </div>
          </div>
        </div>
      </Modal>

      <Modal
        open={catModalOpen}
        title="Tambah Kategori"
        onClose={() => setCatModalOpen(false)}
        footer={
          <>
            <Button variant="secondary" onClick={() => setCatModalOpen(false)}>Batal</Button>
            <Button onClick={submitCategory} disabled={catSaving}>
              {catSaving && <Spinner size={14} className="text-white" />}
              Simpan
            </Button>
          </>
        }
      >
        <div className="space-y-3">
          {catError && (
            <div className="rounded-lg border border-danger/30 bg-danger/5 px-3 py-2 text-xs font-medium text-danger">{catError}</div>
          )}
          <label className="mb-1 block text-xs font-semibold text-textSecondary">Nama Kategori</label>
          <Input
            value={catName}
            onChange={(e) => setCatName(e.target.value)}
            onKeyDown={(e) => { if (e.key === 'Enter') submitCategory() }}
            placeholder="mis. Makanan Ringan"
            autoFocus
          />
        </div>
      </Modal>
    </div>
  )
}
