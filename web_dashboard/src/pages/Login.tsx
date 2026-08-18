import { useCallback, useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { Store } from 'lucide-react'
import { api, ApiError, setToken } from '../lib/api'
import { Button, Input } from './ui'

export default function Login() {
  const navigate = useNavigate()
  const [pin, setPin] = useState('')
  const [error, setError] = useState('')
  const [loading, setLoading] = useState(false)

  const handleSubmit = useCallback(
    async (e: React.FormEvent) => {
      e.preventDefault()
      if (pin.length < 4) {
        setError('PIN minimal 4 digit')
        return
      }
      setLoading(true)
      setError('')
      try {
        const res = await api<{ ok: boolean; pin_set: boolean; token?: string }>(
          '/auth/verify-pin',
          { method: 'POST', body: JSON.stringify({ pin }) }
        )
        if (res.ok && res.token) {
          setToken(res.token)
          navigate('/dashboard', { replace: true })
        } else {
          setError('PIN salah')
          setPin('')
        }
      } catch (e: unknown) {
        if (e instanceof ApiError) {
          if (e.status === 401) {
            setError('PIN salah')
            setPin('')
          } else {
            setError(e.message)
          }
        } else {
          setError('Tidak dapat terhubung ke server')
        }
      } finally {
        setLoading(false)
      }
    },
    [pin, navigate]
  )

  const handleKey = (digit: string) => {
    if (pin.length >= 6) return
    setPin((p) => p + digit)
    setError('')
  }

  const handleBackspace = () => {
    setPin((p) => p.slice(0, -1))
    setError('')
  }

  return (
    <div className="flex min-h-screen items-center justify-center bg-background">
      <div className="w-full max-w-sm px-4">
        <div className="card-shadow rounded-2xl border border-border bg-surface p-8">
          <div className="flex flex-col items-center gap-3 mb-8">
            <div className="rounded-2xl bg-primary/10 p-4">
              <Store size={36} className="text-primary" />
            </div>
            <div className="text-center">
              <h1 className="font-display text-2xl font-extrabold text-textPrimary">KiosKu</h1>
              <p className="text-xs text-textSecondary mt-0.5">Dashboard Manajemen</p>
            </div>
          </div>

          <form onSubmit={handleSubmit} className="space-y-5">
            <div>
              <label className="mb-2 block text-center text-sm font-semibold text-textSecondary">
                Masukkan PIN
              </label>
              <div className="flex justify-center gap-2.5 mb-3">
                {[0, 1, 2, 3, 4, 5].map((i) => (
                  <div
                    key={i}
                    className="h-3 w-3 rounded-full transition-colors"
                    style={{
                      backgroundColor: i < pin.length ? 'var(--color-primary)' : 'var(--color-border)',
                    }}
                  />
                ))}
              </div>
              <Input
                type="password"
                inputMode="numeric"
                maxLength={6}
                placeholder="Masukkan PIN Anda"
                value={pin}
                onChange={(e) => {
                  const v = e.target.value.replace(/\D/g, '').slice(0, 6)
                  setPin(v)
                  setError('')
                }}
                onKeyDown={(e) => {
                  if (e.key === 'Backspace') handleBackspace()
                }}
                autoFocus
                className="text-center text-lg tracking-[0.5em] font-mono"
              />
            </div>

            {error && (
              <p className="text-center text-sm font-semibold text-danger">{error}</p>
            )}

            <Button
              type="submit"
              className="w-full"
              disabled={loading || pin.length < 4}
            >
              {loading ? 'Memverifikasi...' : 'Masuk'}
            </Button>
          </form>
        </div>

        <p className="mt-6 text-center text-xs text-textSecondary">
          KiosKu v1.0 &mdash; Aplikasi Kasir Warung
        </p>
      </div>
    </div>
  )
}
