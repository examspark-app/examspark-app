"""RAG index policy — audio + YouTube only; PDF/photo never stored."""
from unittest.mock import MagicMock, patch

import pytest

from app.services.rag_index_service import is_rag_indexable_source


def test_rag_indexable_sources():
    assert is_rag_indexable_source("recorded")
    assert is_rag_indexable_source("uploaded_audio")
    assert is_rag_indexable_source("youtube_link")
    assert not is_rag_indexable_source("uploaded_document")
    assert not is_rag_indexable_source("pdf_upload")
    assert not is_rag_indexable_source(None)
    assert not is_rag_indexable_source("")


@pytest.mark.asyncio
async def test_ensure_lecture_indexed_skips_pdf_photo():
    from app.services.rag_index_service import ensure_lecture_indexed

    with (
        patch(
            "app.services.rag_index_service._lecture_owned",
            return_value={
                "id": "lec-1",
                "user_id": "u-1",
                "status": "done",
                "source_type": "uploaded_document",
            },
        ),
        patch(
            "app.services.rag_index_service._already_indexed",
            return_value=False,
        ) as already,
        patch(
            "app.services.rag_index_service._index_source",
        ) as index_src,
    ):
        out = await ensure_lecture_indexed("u-1", "lec-1")

    assert out.get("skipped") is True
    assert out.get("chunks") == 0
    already.assert_not_called()
    index_src.assert_not_called()


@pytest.mark.asyncio
async def test_ensure_lecture_indexed_allows_youtube():
    from app.services.rag_index_service import ensure_lecture_indexed

    with (
        patch(
            "app.services.rag_index_service._lecture_owned",
            return_value={
                "id": "lec-2",
                "user_id": "u-1",
                "status": "done",
                "source_type": "youtube_link",
            },
        ),
        patch(
            "app.services.rag_index_service._already_indexed",
            return_value=True,
        ),
        patch("app.services.rag_index_service.get_supabase_admin") as sb,
    ):
        chain = MagicMock()
        chain.select.return_value = chain
        chain.eq.return_value = chain
        chain.execute.return_value = MagicMock(count=3, data=[])
        sb.return_value.table.return_value = chain
        out = await ensure_lecture_indexed("u-1", "lec-2")

    assert out.get("skipped") is not True
    assert out.get("already_indexed") is True
    assert out.get("chunks") == 3
