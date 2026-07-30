"""Admin payment routes — pending UI/backend wiring."""
from fastapi import APIRouter

router = APIRouter(prefix="/api/v1/admin", tags=["admin-payments"])

_TODO = {"status": "pending", "message": "TODO: Admin integration + auth guard"}


@router.get("/payments")
async def list_payments():
    return {**_TODO, "data": []}


@router.get("/subscriptions")
async def list_subscriptions():
    return {**_TODO, "data": []}


@router.get("/payments/failed")
async def list_failed_payments():
    return {**_TODO, "data": []}


@router.get("/refunds")
async def list_refunds():
    return {**_TODO, "data": []}


@router.post("/credits/adjust")
async def manual_credit_adjustment():
    # TODO: Manual credit adjustment with audit log
    return {**_TODO}


@router.get("/transactions")
async def transaction_history():
    return {**_TODO, "data": []}


@router.get("/revenue")
async def revenue_dashboard():
    return {**_TODO, "metrics": {}}
