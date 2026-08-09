import asyncio
from app.services.pyq_retrieve import match_pyqs_for_query

async def main():
    query = "electromagnetic induction physics"
    print(f"Testing query: {query}")
    matches = await match_pyqs_for_query(query)
    print(f"Matches found: {len(matches)}")
    for m in matches:
        print(m)

asyncio.run(main())