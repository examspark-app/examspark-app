-- Optional cleanup: remove any PDF/photo lecture chunks already in RAG
-- (from before the Jul 18 lock: only audio + YouTube go in rag_documents).
-- Safe to re-run. Does NOT delete notes or R2 files — only vector rows.

DELETE FROM public.rag_documents rd
USING public.lectures l
WHERE rd.lecture_id = l.id
  AND l.source_type = 'uploaded_document';

SELECT 'rag_pdf_photo_chunks_removed' AS k,
       (SELECT COUNT(*)::text
        FROM public.rag_documents rd
        JOIN public.lectures l ON l.id = rd.lecture_id
        WHERE l.source_type = 'uploaded_document') AS remaining_should_be_0;
