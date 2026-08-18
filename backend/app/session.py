import secrets
import threading
import time
from dataclasses import dataclass, field

SESSION_EXPIRY_SECONDS = 12 * 60 * 60  # 12 jam
CLEANUP_INTERVAL = 300  # bersihkan setiap 5 menit


@dataclass
class Session:
    token: str
    created_at: float
    expires_at: float


class SessionStore:
    def __init__(self):
        self._sessions: dict[str, Session] = {}
        self._lock = threading.Lock()
        self._last_cleanup = time.time()

    def create(self) -> Session:
        now = time.time()
        token = secrets.token_urlsafe(32)
        session = Session(
            token=token,
            created_at=now,
            expires_at=now + SESSION_EXPIRY_SECONDS,
        )
        with self._lock:
            self._sessions[token] = session
            self._maybe_cleanup(now)
        return session

    def validate(self, token: str) -> bool:
        now = time.time()
        with self._lock:
            self._maybe_cleanup(now)
            session = self._sessions.get(token)
            if session is None:
                return False
            if now > session.expires_at:
                del self._sessions[token]
                return False
            return True

    def invalidate(self, token: str) -> bool:
        with self._lock:
            if token in self._sessions:
                del self._sessions[token]
                return True
            return False

    def _maybe_cleanup(self, now: float):
        if now - self._last_cleanup < CLEANUP_INTERVAL:
            return
        self._last_cleanup = now
        expired = [t for t, s in self._sessions.items() if now > s.expires_at]
        for t in expired:
            del self._sessions[t]


store = SessionStore()
