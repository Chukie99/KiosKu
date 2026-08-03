import { clsx } from 'clsx'
import { twMerge } from 'tailwind-merge'
import {
  AlertTriangle,
  ChevronLeft,
  ChevronRight,
  Inbox,
  Loader2,
  RefreshCw,
  X,
  type LucideIcon,
} from 'lucide-react'
import { useEffect, type ButtonHTMLAttributes, type InputHTMLAttributes, type ReactNode, type SelectHTMLAttributes, type TextareaHTMLAttributes } from 'react'

export function cx(...inputs: Array<string | undefined | false | null>): string {
  return twMerge(clsx(inputs))
}

type ButtonVariant = 'primary' | 'secondary' | 'danger' | 'ghost'
type ButtonSize = 'sm' | 'md'

const BUTTON_BASE =
  'inline-flex items-center justify-center gap-2 rounded-lg font-semibold transition-colors focus:outline-none focus:ring-2 focus:ring-primary/40 disabled:cursor-not-allowed disabled:opacity-50'

const BUTTON_VARIANTS: Record<ButtonVariant, string> = {
  primary: 'bg-primary text-white hover:bg-primaryDark',
  secondary: 'bg-surface text-textPrimary border border-border hover:bg-background',
  danger: 'bg-danger text-white hover:bg-red-700',
  ghost: 'bg-transparent text-textSecondary hover:bg-background',
}

const BUTTON_SIZES: Record<ButtonSize, string> = {
  sm: 'px-3 py-1.5 text-xs',
  md: 'px-4 py-2 text-sm',
}

export function Button({
  variant = 'primary',
  size = 'md',
  className,
  ...props
}: ButtonHTMLAttributes<HTMLButtonElement> & { variant?: ButtonVariant; size?: ButtonSize }) {
  return <button className={cx(BUTTON_BASE, BUTTON_VARIANTS[variant], BUTTON_SIZES[size], className)} {...props} />
}

export function Card({ className, children }: { className?: string; children: ReactNode }) {
  return <div className={cx('card-shadow rounded-xl border border-border bg-surface', className)}>{children}</div>
}

const INPUT_CLASSES =
  'w-full rounded-lg border border-border bg-white px-3 py-2 text-sm text-textPrimary placeholder:text-textSecondary/60 outline-none transition-colors focus:border-primary focus:ring-2 focus:ring-primary/20'

export function Input({ className, ...props }: InputHTMLAttributes<HTMLInputElement>) {
  return <input className={cx(INPUT_CLASSES, className)} {...props} />
}

export function Select({ className, children, ...props }: SelectHTMLAttributes<HTMLSelectElement>) {
  return (
    <select className={cx(INPUT_CLASSES, 'cursor-pointer appearance-none pr-8', className)} {...props}>
      {children}
    </select>
  )
}

export function Textarea({ className, ...props }: TextareaHTMLAttributes<HTMLTextAreaElement>) {
  return <textarea className={cx(INPUT_CLASSES, 'min-h-[80px] resize-y', className)} {...props} />
}

type BadgeColor = 'green' | 'amber' | 'red' | 'slate' | 'primary' | 'warning' | 'danger' | 'success'

const BADGE_COLORS: Record<BadgeColor, string> = {
  green: 'bg-success/10 text-success',
  success: 'bg-success/10 text-success',
  amber: 'bg-warning/10 text-warning',
  warning: 'bg-warning/10 text-warning',
  red: 'bg-danger/10 text-danger',
  danger: 'bg-danger/10 text-danger',
  slate: 'bg-slate-100 text-textSecondary',
  primary: 'bg-primary/10 text-primary',
}

export function Badge({ color = 'slate', className, children }: { color?: BadgeColor; className?: string; children: ReactNode }) {
  return (
    <span className={cx('inline-flex items-center gap-1 whitespace-nowrap rounded-full px-2.5 py-0.5 text-xs font-semibold', BADGE_COLORS[color], className)}>
      {children}
    </span>
  )
}

export function Modal({
  open,
  title,
  onClose,
  children,
  footer,
  wide,
}: {
  open: boolean
  title: string
  onClose: () => void
  children: ReactNode
  footer?: ReactNode
  wide?: boolean
}) {
  useEffect(() => {
    if (!open) return
    const onKey = (e: KeyboardEvent) => {
      if (e.key === 'Escape') onClose()
    }
    window.addEventListener('keydown', onKey)
    return () => window.removeEventListener('keydown', onKey)
  }, [open, onClose])

  if (!open) return null
  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4">
      <div className="absolute inset-0 bg-slate-900/50" onClick={onClose} />
      <div className={cx('card-shadow relative flex max-h-[90vh] w-full flex-col rounded-xl bg-surface', wide ? 'max-w-3xl' : 'max-w-lg')}>
        <div className="flex items-center justify-between border-b border-border px-6 py-4">
          <h3 className="text-base font-bold text-textPrimary">{title}</h3>
          <button onClick={onClose} className="rounded-lg p-1 text-textSecondary transition-colors hover:bg-background hover:text-textPrimary" aria-label="Tutup">
            <X size={18} />
          </button>
        </div>
        <div className="flex-1 overflow-y-auto px-6 py-5">{children}</div>
        {footer && <div className="flex items-center justify-end gap-2 border-t border-border px-6 py-4">{footer}</div>}
      </div>
    </div>
  )
}

export function Table({ className, children }: { className?: string; children: ReactNode }) {
  return (
    <div className={cx('overflow-x-auto rounded-xl border border-border bg-surface', className)}>
      <table className="w-full min-w-full text-left text-sm">{children}</table>
    </div>
  )
}

export function Thead({ children }: { children: ReactNode }) {
  return (
    <thead className="bg-background text-xs uppercase tracking-wide text-textSecondary">
      <tr>{children}</tr>
    </thead>
  )
}

export function Th({ className, children }: { className?: string; children?: ReactNode }) {
  return <th className={cx('px-4 py-3 font-semibold', className)}>{children}</th>
}

export function Td({ className, children }: { className?: string; children?: ReactNode }) {
  return <td className={cx('px-4 py-3 align-middle', className)}>{children}</td>
}

export function Tr({ className, children, onClick }: { className?: string; children: ReactNode; onClick?: () => void }) {
  return (
    <tr className={cx('border-t border-border transition-colors', onClick ? 'cursor-pointer hover:bg-background/60' : 'hover:bg-background/40', className)} onClick={onClick}>
      {children}
    </tr>
  )
}

export function SkeletonRow({ cols, height = 'h-4' }: { cols: number; height?: string }) {
  return (
    <tr className="border-t border-border">
      {Array.from({ length: cols }).map((_, i) => (
        <td key={i} className="px-4 py-3.5">
          <div className={cx('animate-pulse rounded-md bg-slate-200/70', height)} />
        </td>
      ))}
    </tr>
  )
}

export function SkeletonCard({ className }: { className?: string }) {
  return <div className={cx('card-shadow h-28 animate-pulse rounded-xl border border-border bg-surface', className)} />
}

export function EmptyState({ icon: Icon = Inbox, message }: { icon?: LucideIcon; message: string }) {
  return (
    <div className="flex flex-col items-center justify-center gap-2 py-10 text-textSecondary">
      <div className="rounded-full bg-background p-3">
        <Icon size={22} />
      </div>
      <p className="text-sm">{message}</p>
    </div>
  )
}

export function ErrorState({ message, onRetry }: { message: string; onRetry: () => void }) {
  return (
    <div className="flex flex-col items-center justify-center gap-3 rounded-xl border border-danger/20 bg-danger/5 py-10">
      <AlertTriangle size={24} className="text-danger" />
      <p className="text-sm font-semibold text-danger">{message}</p>
      <Button variant="secondary" size="sm" onClick={onRetry}>
        <RefreshCw size={14} /> Coba Lagi
      </Button>
    </div>
  )
}

export function Spinner({ size = 24, className }: { size?: number; className?: string }) {
  return <Loader2 size={size} className={cx('animate-spin text-primary', className)} />
}

export function PaginationBar({
  page,
  pageSize,
  total,
  onPage,
}: {
  page: number
  pageSize: number
  total: number
  onPage: (page: number) => void
}) {
  const totalPages = Math.max(1, Math.ceil(total / pageSize))
  const from = total === 0 ? 0 : (page - 1) * pageSize + 1
  const to = Math.min(page * pageSize, total)
  return (
    <div className="flex flex-wrap items-center justify-between gap-3 px-1 pt-4">
      <p className="text-xs text-textSecondary">
        Menampilkan {from}–{to} dari {total} data
      </p>
      <div className="flex gap-2">
        <Button variant="secondary" size="sm" disabled={page <= 1} onClick={() => onPage(page - 1)}>
          <ChevronLeft size={14} /> Sebelumnya
        </Button>
        <Button variant="secondary" size="sm" disabled={page >= totalPages} onClick={() => onPage(page + 1)}>
          Berikutnya <ChevronRight size={14} />
        </Button>
      </div>
    </div>
  )
}
