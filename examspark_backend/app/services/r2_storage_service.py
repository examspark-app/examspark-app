"""Cloudflare R2 (S3-compatible) — permanent storage for lecture content.

PROJECT_CORE_RULES.md / DATA_STORAGE_POLICY.md: Postgres holds paths only.

Canonical layout (Session 4):
  Users/{user_id}/Library/{lecture_id}/...
  Teachers/{teacher_id}/Groups/{group_id}/shared/...
  Exports/{user_id}/...

Legacy prefix still readable: Library/{user_id}/{lecture_id}/...
(Postgres stores the full key — old lectures keep working without migration.)
"""
from __future__ import annotations

import json
import re
from pathlib import PurePosixPath

import boto3
from botocore.config import Config as BotoConfig

from app.config import StorageConfig

# Canonical filenames under a lecture folder (DATA_STORAGE_POLICY.md).
FILE_TRANSCRIPT = "transcript.txt"
FILE_CLEAN_TRANSCRIPT = "clean_transcript.txt"
FILE_NOTES = "notes.json"
FILE_SUMMARY = "summary.txt"
FILE_KEY_POINTS = "key_points.json"
FILE_IMPORTANT_TERMS = "important_terms.json"
FILE_FLASHCARDS = "flashcards.json"
FILE_QUIZ = "quiz.json"
FILE_REVISION = "revision.json"
FILE_MINDMAP = "mindmap.json"
FILE_FORMULA = "formula.json"


class R2StorageError(Exception):
    pass


def _safe_filename(name: str | None, default: str = "source.bin") -> str:
    raw = (name or default).strip().replace("\\", "/")
    base = PurePosixPath(raw).name or default
    base = re.sub(r"[^\w.\-]+", "_", base, flags=re.UNICODE)
    return base[:180] or default


class R2StorageService:
    def __init__(self):
        self._client = None

    def _get_client(self):
        if not StorageConfig.configured():
            raise R2StorageError(
                "R2 storage not configured — set CLOUDFLARE_ACCOUNT_ID, R2_BUCKET_NAME, "
                "R2_ACCESS_KEY_ID, R2_SECRET_ACCESS_KEY in .env."
            )
        if self._client is None:
            self._client = boto3.client(
                "s3",
                endpoint_url=StorageConfig.endpoint_url(),
                aws_access_key_id=StorageConfig.R2_ACCESS_KEY_ID,
                aws_secret_access_key=StorageConfig.R2_SECRET_ACCESS_KEY,
                config=BotoConfig(signature_version="s3v4"),
                region_name="auto",
            )
        return self._client

    # --- Path builders (Session 4 conventions) ---

    def lecture_folder_path(self, user_id: str, lecture_id: str) -> str:
        """Primary lecture content root — matches schema.sql comment."""
        return f"Users/{user_id}/Library/{lecture_id}"

    def legacy_lecture_folder_path(self, user_id: str, lecture_id: str) -> str:
        """Pre–Session 4 prefix (still present on older objects)."""
        return f"Library/{user_id}/{lecture_id}"

    def lecture_file_path(self, user_id: str, lecture_id: str, filename: str) -> str:
        return f"{self.lecture_folder_path(user_id, lecture_id)}/{filename}"

    def teacher_group_shared_folder(self, teacher_id: str, group_id: str) -> str:
        return f"Teachers/{teacher_id}/Groups/{group_id}/shared"

    def export_folder_path(self, user_id: str) -> str:
        return f"Exports/{user_id}"

    def export_file_path(self, user_id: str, filename: str) -> str:
        return f"{self.export_folder_path(user_id)}/{_safe_filename(filename)}"

    def source_document_path(
        self, user_id: str, lecture_id: str, filename: str | None
    ) -> str:
        """Uploaded PDF/image kept for the library (never raw audio)."""
        return self.lecture_file_path(
            user_id, lecture_id, f"source/{_safe_filename(filename, 'source.bin')}"
        )

    def rag_chunk_path(
        self, user_id: str, lecture_id: str, source_type: str, chunk_hash: str
    ) -> str:
        return (
            f"{self.lecture_folder_path(user_id, lecture_id)}"
            f"/rag/{source_type}/{chunk_hash[:16]}.txt"
        )

    # --- Upload / download ---

    def upload_text(self, path: str, content: str, content_type: str = "text/plain") -> str:
        client = self._get_client()
        try:
            client.put_object(
                Bucket=StorageConfig.R2_BUCKET_NAME,
                Key=path,
                Body=content.encode("utf-8"),
                ContentType=content_type,
            )
        except Exception as e:  # noqa: BLE001
            raise R2StorageError(f"R2 upload failed for {path}: {e}") from e
        return path

    def upload_json(self, path: str, data: dict | list) -> str:
        return self.upload_text(
            path, json.dumps(data, ensure_ascii=False), content_type="application/json"
        )

    def upload_bytes(
        self, path: str, data: bytes, content_type: str = "application/octet-stream"
    ) -> str:
        client = self._get_client()
        try:
            client.put_object(
                Bucket=StorageConfig.R2_BUCKET_NAME,
                Key=path,
                Body=data,
                ContentType=content_type,
            )
        except Exception as e:  # noqa: BLE001
            raise R2StorageError(f"R2 upload failed for {path}: {e}") from e
        return path

    def download_text(self, path: str) -> str:
        client = self._get_client()
        try:
            response = client.get_object(Bucket=StorageConfig.R2_BUCKET_NAME, Key=path)
            body = response["Body"].read()
        except Exception as e:  # noqa: BLE001
            raise R2StorageError(f"R2 download failed for {path}: {e}") from e
        return body.decode("utf-8")

    def download_json(self, path: str) -> dict:
        return json.loads(self.download_text(path))

    def download_bytes(self, path: str) -> bytes:
        client = self._get_client()
        try:
            response = client.get_object(Bucket=StorageConfig.R2_BUCKET_NAME, Key=path)
            return response["Body"].read()
        except Exception as e:  # noqa: BLE001
            raise R2StorageError(f"R2 download failed for {path}: {e}") from e
