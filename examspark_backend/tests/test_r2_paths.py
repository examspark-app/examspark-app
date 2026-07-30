"""Session 4 — R2 path builders (no network)."""
from app.services.r2_storage_service import (
    FILE_NOTES,
    FILE_TRANSCRIPT,
    R2StorageService,
)


def test_lecture_folder_is_users_library_layout():
    r2 = R2StorageService()
    assert (
        r2.lecture_folder_path("uid-1", "lec-2")
        == "Users/uid-1/Library/lec-2"
    )


def test_legacy_folder_kept_for_docs():
    r2 = R2StorageService()
    assert r2.legacy_lecture_folder_path("uid-1", "lec-2") == "Library/uid-1/lec-2"


def test_lecture_file_and_source_paths():
    r2 = R2StorageService()
    assert (
        r2.lecture_file_path("u", "l", FILE_NOTES)
        == "Users/u/Library/l/notes.json"
    )
    assert (
        r2.source_document_path("u", "l", "Photo Scan.JPG")
        == "Users/u/Library/l/source/Photo_Scan.JPG"
    )
    assert r2.lecture_file_path("u", "l", FILE_TRANSCRIPT).endswith(
        "/transcript.txt"
    )


def test_teacher_and_export_paths():
    r2 = R2StorageService()
    assert (
        r2.teacher_group_shared_folder("t1", "g1")
        == "Teachers/t1/Groups/g1/shared"
    )
    assert r2.export_file_path("u1", "notes.pdf") == "Exports/u1/notes.pdf"


def test_rag_chunk_path():
    r2 = R2StorageService()
    path = r2.rag_chunk_path("u", "l", "notes", "abcdef0123456789zzzz")
    assert path == "Users/u/Library/l/rag/notes/abcdef0123456789.txt"
