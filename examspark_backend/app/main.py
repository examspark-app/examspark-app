"""
Compatibility shim.

Some startup commands were mistakenly using `uvicorn app.main:app`, but the
canonical FastAPI app lives in `c:/Users/.../ExamSpark-Project/examspark_backend/main.py`.

Keeping this re-export prevents `Could not import module "app.main"` errors
and makes startup resilient to that mistaken module path.
"""

from main import app  # type: ignore[F401]

__all__ = ["app"]

