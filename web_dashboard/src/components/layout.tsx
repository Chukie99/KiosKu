import { useCallback, useEffect, useState } from 'react'
import { NavLink, Outlet, useLocation, useNavigate } from 'react-router-dom'
import {
  BarChart3,
  LayoutDashboard,
  LogOut,
  Package,
  PackageCheck,
  Settings,
  Store,
  Wallet,
  Wifi,
  WifiOff,
} from 'lucide-react'
import { api, clearToken } from '../lib/api'
import { cx } from './ui'

const NAV_ITEMS = [
  { to: '/dashboard', label: 'Dashboard', icon: LayoutDashboard },
  { to: '/reports', label: 'Laporan', icon: BarChart3 },
  { to: '/products', label: 'Produk', icon: Package },
  { to: '/stock', label: 'Stok', icon: PackageCheck },
  { to: '/debts', label: 'Utang', icon: Wallet },
  { to: '/settings', label: 'Pengaturan', icon: Settings },
]

const PAGE_TITLES: Record<string, string> = {
  '/dashboard': 'Dashboard',
  '/reports': 'Laporan Penjualan',
  '/products': 'Produk',
  '/stock': 'Stok & Riwayat',
  '/debts': 'Utang Pelanggan',
  '/settings': 'Pengaturan',
}

export default function Layout() {
  const location = useLocation()
  const navigate = useNavigate()
  const [now, setNow] = useState(new Date())
  const [online, setOnline] = useState<boolean | null>(null)

  const handleLogout = useCallback(async () => {
    try {
      await api('/auth/logout', { method: 'POST' })
    } catch {
      // ignore error
    }
    clearToken()
    navigate('/login', { replace: true })
  }, [navigate])

  useEffect(() => {
    const timer = setInterval(() => setNow(new Date()), 1000)
    return () => clearInterval(timer)
  }, [])

  useEffect(() => {
    let cancelled = false
    const check = async () => {
      try {
        const res = await api<{ status: string }>('/health')
        if (!cancelled) setOnline(res.status === 'ok')
      } catch {
        if (!cancelled) setOnline(false)
      }
    }
    check()
    const timer = setInterval(check, 10000)
    return () => {
      cancelled = true
      clearInterval(timer)
    }
  }, [])

  const title = PAGE_TITLES[location.pathname] ?? 'KiosKu'

  return (
    <div className="flex h-screen overflow-hidden">
      <aside className="hidden w-60 flex-col bg-accentGreen md:flex">
        <div className="flex items-center gap-3 px-5 py-6">
          <div className="rounded-xl bg-primary p-2.5 shadow-lg shadow-black/20">
            <Store size={22} className="text-white" />
          </div>
          <div>
            <p className="font-display text-lg font-extrabold leading-tight text-white">KiosKu</p>
            <p className="text-[11px] font-medium text-slate-400">Point of Sale</p>
          </div>
        </div>
        <nav className="flex-1 space-y-1 overflow-y-auto px-3 py-2">
          {NAV_ITEMS.map((item) => (
            <NavLink
              key={item.to}
              to={item.to}
              className={({ isActive }) =>
                cx(
                  'flex items-center gap-3 rounded-lg px-3 py-2.5 text-sm font-medium transition-colors',
                  isActive ? 'bg-primary/85 text-white shadow-md shadow-black/20' : 'text-slate-300 hover:bg-white/5 hover:text-white'
                )
              }
            >
              <item.icon size={18} />
              {item.label}
            </NavLink>
          ))}
        </nav>
        <div className="px-5 py-4">
          <p className="text-xs text-slate-400">KiosKu v1.0</p>
        </div>
      </aside>

      <div className="flex min-w-0 flex-1 flex-col">
        <header className="flex h-16 shrink-0 items-center justify-between gap-4 border-b border-border bg-surface px-6">
          <div className="flex items-center gap-3">
            <div className="flex items-center gap-2 md:hidden">
              <div className="rounded-lg bg-primary p-1.5">
                <Store size={16} className="text-white" />
              </div>
              <span className="text-sm font-extrabold text-white">KiosKu</span>
            </div>
            <div>
              <h1 className="font-display text-lg font-bold leading-tight text-textPrimary">{title}</h1>
              <p className="hidden text-xs text-textSecondary sm:block">Panel manajemen KiosKu</p>
            </div>
          </div>
          <div className="flex items-center gap-4">
            <div className="hidden text-right sm:block">
              <p className="text-sm font-semibold tabular-nums text-textPrimary">
                {now.toLocaleTimeString('id-ID', { hour: '2-digit', minute: '2-digit', second: '2-digit' })}
              </p>
              <p className="text-[11px] text-textSecondary">
                {now.toLocaleDateString('id-ID', { weekday: 'long', day: 'numeric', month: 'long', year: 'numeric' })}
              </p>
            </div>
            <div className="h-8 w-px bg-border" />
            <div
              className={cx(
                'flex items-center gap-1.5 rounded-full border px-3 py-1.5 text-xs font-semibold',
                online === null && 'border-border bg-background text-textSecondary',
                online === true && 'border-success/30 bg-success/10 text-success',
                online === false && 'border-danger/30 bg-danger/10 text-danger'
              )}
            >
              {online === true && <Wifi size={13} />}
              {online === false && <WifiOff size={13} />}
              {online === null ? 'Memeriksa...' : online ? 'Online' : 'Offline'}
            </div>
            <button
              onClick={handleLogout}
              className="flex items-center gap-1.5 rounded-lg border border-border px-3 py-1.5 text-xs font-semibold text-textSecondary transition-colors hover:bg-danger/10 hover:text-danger hover:border-danger/30"
              title="Keluar"
            >
              <LogOut size={14} />
              <span className="hidden sm:inline">Keluar</span>
            </button>
          </div>
        </header>

        <main className="flex-1 overflow-y-auto bg-background p-6">
          <div className="mx-auto max-w-[1440px]">
            <Outlet />
          </div>
        </main>
      </div>
    </div>
  )
}
