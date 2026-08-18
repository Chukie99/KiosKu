import { useCallback, useEffect, useState } from 'react'
import {
  ArchiveRestore,
  CheckCircle2,
  Database,
  FileDown,
  Save,
  Server,
  Store,
} from 'lucide-react'
import { api, errMsg } from '../lib/api'
import { formatTanggalWaktu } from '../lib/format'
import type { BackupFile, HealthInfo, SettingsInfo } from '../lib/types'
import {
  Badge,
  Button,
  Card,
  ErrorState,
  Input,
  SkeletonCard,
  Spinner,
} from '../components/ui'

function formatSize(bytes: number): string {
  if (bytes >= 1_048_576) return `${(bytes / 1_048_576).toFixed(1)} MB`
  return `${Math.max(1, Math.round(bytes / 1024))} KB`
}

export default function Settings() {
  const [settings, setSettings] = useState<SettingsInfo | null>(null)
  const [health, setHealth] = useState<HealthInfo | null>(null)
  const [backups, setBackups] = useState<BackupFile[]>([])
  const [storeName, setStoreName] = useState('')
  const [saved, setSaved] = useState(false)
  const [savingStore, setSavingStore] = useState(false)
  const [storeError, setStoreError] = useState<string | null>(null)
  const [busy, setBusy] = useState<'backup' | 'restore' | null>(null)
  const [restoreNote, setRestoreNote] = useState<string | null>(null)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)

  const load = useCallback(async () => {
    setLoading(true)
    setError(null)
    try {
      const [s, b, h] = await Promise.all([
        api<SettingsInfo>('/settings'),
        api<BackupFile[]>('/backup/list'),
        api<HealthInfo>('/health'),
      ])
      setSettings(s)
      setStoreName(s.store_name)
      setBackups(b)
      setHealth(h)
    } catch (e) {
      setError(errMsg(e))
    } finally {
      setLoading(false)
    }
  }, [])

  useEffect(() => {
    load()
  }, [load])

  const saveStore = async () => {
    if (!storeName.trim()) {
      setStoreError('Nama toko wajib diisi')
      return
    }
    setSavingStore(true)
    setStoreError(null)
    try {
      const res = await api<SettingsInfo>('/settings', { method: 'PUT', body: JSON.stringify({ store_name: storeName.trim() }) })
      setSettings(res)
      setSaved(true)
      setTimeout(() => setSaved(false), 2500)
    } catch (e) {
      setStoreError(errMsg(e))
    } finally {
      setSavingStore(false)
    }
  }

  const doBackup = async () => {
    setBusy('backup')
    setRestoreNote(null)
    try {
      await api('/backup/trigger', { method: 'POST' })
      setBackups(await api<BackupFile[]>('/backup/list'))
    } catch (e) {
      setError(errMsg(e))
    } finally {
      setBusy(null)
    }
  }

  const doRestore = async (file: BackupFile) => {
    if (!window.confirm(`Pulihkan data dari backup "${file.filename}"? Data saat ini akan dibuatkan backup otomatis sebelum dipulihkan.`)) return
    setBusy('restore')
    setRestoreNote(null)
    try {
      const res = await api<{ ok: boolean; note: string }>(`/backup/restore?filename=${encodeURIComponent(file.filename)}`, { method: 'POST' })
      setRestoreNote(res.note)
    } catch (e) {
      setError(errMsg(e))
    } finally {
      setBusy(null)
    }
  }

  if (loading) {
    return (
      <div className="space-y-6">
        <SkeletonCard className="h-44" />
        <SkeletonCard className="h-80" />
        <SkeletonCard className="h-32" />
      </div>
    )
  }

  if (error) return <ErrorState message={error} onRetry={load} />

  return (
    <div className="space-y-6">
      <Card className="p-6">
        <div className="mb-4 flex items-center gap-2">
          <Store size={18} className="text-primary" />
          <h2 className="text-base font-bold text-textPrimary">Informasi Toko</h2>
        </div>
        <div className="max-w-md space-y-3">
          <div>
            <label className="mb-1 block text-xs font-semibold text-textSecondary">Nama Toko</label>
            <Input value={storeName} onChange={(e) => setStoreName(e.target.value)} placeholder="Nama toko" />
          </div>
          {storeError && (
            <div className="rounded-lg border border-danger/30 bg-danger/5 px-3 py-2 text-xs font-medium text-danger">{storeError}</div>
          )}
          <div className="flex items-center gap-3">
            <Button onClick={saveStore} disabled={savingStore}>
              {savingStore ? <Spinner size={14} className="text-white" /> : <Save size={15} />}
              Simpan Nama Toko
            </Button>
            {saved && (
              <span className="flex items-center gap-1 text-xs font-semibold text-success">
                <CheckCircle2 size={14} /> Tersimpan
              </span>
            )}
          </div>
          {settings && (
            <p className="text-xs text-textSecondary">
              Status PIN: <Badge color={settings.pin_set ? 'green' : 'amber'}>{settings.pin_set ? 'Terpasang' : 'Belum diatur'}</Badge>{' '}
              · Backup otomatis: <Badge color={settings.backup_enabled ? 'green' : 'slate'}>{settings.backup_enabled ? 'Aktif' : 'Nonaktif'}</Badge>{' '}
              · Jadwal: {settings.backup_hour}
            </p>
          )}
        </div>
      </Card>

      <Card className="p-6">
        <div className="mb-4 flex items-center justify-between gap-3">
          <div className="flex items-center gap-2">
            <Database size={18} className="text-primary" />
            <div>
              <h2 className="text-base font-bold text-textPrimary">Backup Database</h2>
              <p className="text-xs text-textSecondary">Cadangkan data toko ke file backup (.db)</p>
            </div>
          </div>
          <Button onClick={doBackup} disabled={busy !== null}>
            {busy === 'backup' ? <Spinner size={14} className="text-white" /> : <FileDown size={15} />}
            Backup Sekarang
          </Button>
        </div>

        {restoreNote && (
          <div className="mb-4 flex items-center gap-2 rounded-lg border border-warning/30 bg-warning/5 px-4 py-3 text-sm text-warning">
            <ArchiveRestore size={16} />
            {restoreNote}
          </div>
        )}

        {backups.length === 0 ? (
          <p className="rounded-lg border border-dashed border-border px-4 py-8 text-center text-sm text-textSecondary">
            Belum ada file backup. Klik "Backup Sekarang" untuk membuat cadangan pertama.
          </p>
        ) : (
          <div className="space-y-2">
            {backups.map((b) => (
              <div key={b.filename} className="flex flex-wrap items-center justify-between gap-3 rounded-lg border border-border bg-background/50 px-4 py-3">
                <div className="min-w-0">
                  <p className="truncate text-sm font-medium text-textPrimary">{b.filename}</p>
                  <p className="text-xs text-textSecondary">
                    {formatSize(b.size)} · {formatTanggalWaktu(b.created_at)}
                  </p>
                </div>
                <Button variant="secondary" size="sm" disabled={busy !== null} onClick={() => doRestore(b)}>
                  {busy === 'restore' ? <Spinner size={13} /> : <ArchiveRestore size={13} />}
                  Restore
                </Button>
              </div>
            ))}
          </div>
        )}
      </Card>

      <Card className="p-6">
        <div className="mb-4 flex items-center gap-2">
          <Server size={18} className="text-accentGreen" />
          <h2 className="text-base font-bold text-textPrimary">Info Server</h2>
        </div>
        {health && (
          <div className="grid grid-cols-1 gap-4 text-sm sm:grid-cols-3">
            <div>
              <p className="text-xs text-textSecondary">Status</p>
              <p className="mt-1 font-semibold text-textPrimary">
                <Badge color={health.status === 'ok' ? 'green' : 'red'}>{health.status === 'ok' ? 'Sehat' : 'Bermasalah'}</Badge>
              </p>
            </div>
            <div>
              <p className="text-xs text-textSecondary">Aplikasi</p>
              <p className="mt-1 font-semibold text-textPrimary">{health.app}</p>
            </div>
            <div>
              <p className="text-xs text-textSecondary">Waktu Server</p>
              <p className="mt-1 font-semibold text-textPrimary">{formatTanggalWaktu(health.time)}</p>
            </div>
          </div>
        )}
      </Card>

      <p className="text-xs text-textSecondary">
        Nama toko saat ini: <span className="font-semibold text-textPrimary">{settings?.store_name ?? '-'}</span>
      </p>
    </div>
  )
}
