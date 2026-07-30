FROM python:3.11-slim

WORKDIR /app

# ffmpeg/ffprobe: long Record/upload Whisper chunking (up to 3 hr)
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    ffmpeg \
    && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

EXPOSE 8000

# Railway/production sets $PORT; default to 8000 for local `docker run`
ENV PORT=8000

CMD ["sh", "-c", "uvicorn main:app --host 0.0.0.0 --port ${PORT}"]
