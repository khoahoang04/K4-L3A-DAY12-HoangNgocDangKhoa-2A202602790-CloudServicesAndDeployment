# ═══════════════════════════════════════════════════════════════════
# CP2 — Multi-stage build
# Stage builder: cài thư viện (được phép nặng, bị vứt đi sau)
# Stage runtime: chỉ copy kết quả → image nhỏ, không mang compiler
# ═══════════════════════════════════════════════════════════════════

# ── Stage 1: builder ─────────────────────────────────────────────
FROM python:3.11-slim AS builder

WORKDIR /install

COPY requirements.txt .

RUN pip install --no-cache-dir --prefix=/install -r requirements.txt


# ── Stage 2: runtime ─────────────────────────────────────────────
FROM python:3.11-slim AS runtime

WORKDIR /app

# Copy chỉ kết quả build (thư viện đã cài) từ stage builder
COPY --from=builder /install /usr/local

# Tạo user thường — không chạy bằng root
RUN useradd --create-home --uid 10001 appuser

# Copy source code (sau pip install để tận dụng Docker cache layer)
COPY app ./app
COPY utils ./utils

USER appuser

EXPOSE 8000

HEALTHCHECK --interval=30s --timeout=5s --retries=3 \
    CMD python -c "import urllib.request; urllib.request.urlopen('http://127.0.0.1:8000/health').read()" || exit 1

CMD ["sh", "-c", "uvicorn app.main:app --host 0.0.0.0 --port ${PORT:-8000}"]
