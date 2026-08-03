export class ApiError extends Error {
  status: number

  constructor(status: number, message: string) {
    super(message)
    this.status = status
  }
}

export function errMsg(e: unknown): string {
  if (e instanceof Error && e.message) return e.message
  return 'Terjadi kesalahan tak terduga'
}

export async function api<T>(path: string, options: RequestInit = {}): Promise<T> {
  const headers: Record<string, string> = {
    ...((options.headers ?? {}) as Record<string, string>),
  }
  if (options.body && typeof options.body === 'string') {
    headers['Content-Type'] = 'application/json'
  }
  let res: Response
  try {
    res = await fetch(path, { ...options, headers })
  } catch {
    throw new ApiError(0, 'Tidak dapat terhubung ke server')
  }
  if (!res.ok) {
    let message = `Terjadi kesalahan (${res.status})`
    try {
      const data = await res.json()
      if (typeof data.detail === 'string') {
        message = data.detail
      } else if (Array.isArray(data.detail)) {
        message = data.detail
          .map((d: { msg?: string }) => d.msg ?? '')
          .filter(Boolean)
          .join(', ')
      }
    } catch {
      // body bukan JSON
    }
    throw new ApiError(res.status, message)
  }
  const contentType = res.headers.get('content-type') ?? ''
  if (contentType.includes('application/json')) {
    return res.json() as Promise<T>
  }
  return res.text() as unknown as Promise<T>
}
