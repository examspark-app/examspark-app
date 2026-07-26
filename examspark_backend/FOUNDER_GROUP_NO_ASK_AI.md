# Group share — no Ask AI (Jul 26, 2026)

## Rule
**Ask AI is never shared to Groups.**

Students who open a shared lecture see Notes / Quiz / … only (what teacher picked).  
No Ask AI tab · no Ask AI selection bar.

## Code
- `SelectableStudyText(enableAskAi: false)` when Study Workspace `readOnly` (group open)
- Share picker / server strip `ask_ai` if ever sent
- Ask AI tab already excluded for shared chips

## Test
1. Flutter hot restart
2. Student: open shared group lecture → **no Ask AI** tab, **no Ask AI** bar on Notes
3. Teacher share sheet: still Notes/Quiz/… only (Ask AI was never a share chip)

## Manual setup
- No SQL · No .env
