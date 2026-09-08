# GlowGuide Credits UX Implementation Plan

## Repository Research — Current State

**Backend (already working, values need UPDATE):**
- `glow_guide_service.py` line 30-32: `GLOW_GUIDE_TEXT_COST=2`, `GLOW_GUIDE_PHOTO_COST=8`, `GLOW_GUIDE_RESEARCH_COST=10`
- `glow_guide_credit_cost()` → line 52-54 returns 2/8
- Pre-check (line 611-613) + post-research check (line 801-805) + `deduct_credits(..., action="glow_guide")` (line 806-809) — all correct
- Response includes `credits_charged` + `new_balance` (line 890) — correct
- Test: `test_glow_guide_credit_cost.py` asserts 2/8 — MUST update

**Frontend Audit Findings (from previous audit):**
1. ❌ `glow_guide_screen.dart` NEVER reads `credits_charged` or `new_balance` from response
2. ❌ Top-bar CreditsPill balance NOT refreshed after a turn (no `SessionLiveSync.refreshAll()` call)
3. ❌ User NOT shown "X credits" label on AI message bubble (unlike Select AI / Home AI tools)
4. ❌ `_sendSilentTurn()` (Gender/Age chip taps) charges 5 credits silently — user ko pata hi nahi chalta
5. ❌ `CreditCosts.dart` mein koi GlowGuide constant nahi hai → `getCostForAction()` returns 0 for 'glow_guide'
6. ❌ `CreditHistoryDisplay.filterBucket()` mein 'glow_guide' kisi bucket mein nahi → only "All" mein dikhta hai
7. ❌ Insufficient credits → SnackBar hi dikhta hai (like home_tab), koi AlertDialog with "Buy Credits" button nahi
8. ❌ Har chip/button pe cost badge nahi dikhta (user ne specifically manga hai)

**Existing patterns (from other modules to reuse):**
- **Insufficient credits SnackBar pattern:** `home_tab.dart` line 1067-1073 → showSnackBar + text
- **Insufficient credits Dialog pattern:** `notes_result_screen.dart` line 345-360 → AlertDialog + "Cancel" + "View Plans" button → `Navigator.pushNamed('/subscription')`
- **Cost on result:** `select_ai_result_sheet.dart` line 232-238 → `Text('${_done!['credits_charged']} credits', bodySmall)` at bottom-right
- **Cost badge on chip/button:** Currently no direct example → implement as trailing Text/Container badge (Icon + "5C" compact)
- **Balance refresh:** `SessionLiveSync.instance.refreshAll()` → updates `creditsBalance` + notifies → CreditsPill listens
- **Read new_balance:** `home_ai_tool_result_sheet.dart` line 113-116 → `widget.onCreditsUpdated?.call(balance)` then app-level sync

## User Request (Decoded)
1. **Cost change:** Text = 5 credits, Photo/Vision = 10 credits, Tavily/Web-search = +10 credits (unchanged)
2. **Insufficient credits → easy popup:** AlertDialog showing "Need X credits for this" + 1-click "Buy Credits" button → `/subscription`
3. **Har chip pe cost dikhaye:** Every tappable chip/button pe compact cost badge (e.g. "· 5 credits" ya "5C")
4. **Previous pending issues:** Sab resolve karo — credits_charged read, balance refresh, history filter, constants

## Files and Modules

### Backend
| File | Change |
|---|---|
| `examspark_backend/app/services/glow_guide_service.py` | Update `GLOW_GUIDE_TEXT_COST=5`, `GLOW_GUIDE_PHOTO_COST=10`; update docstring |
| `examspark_backend/tests/test_glow_guide_credit_cost.py` | Update asserts: text=5, photo=10 |

### Frontend
| File | Change |
|---|---|
| `examspark_frontend/lib/core/constants/credit_costs.dart` | Add `glowGuideText=5`, `glowGuidePhoto=10`, `glowGuideResearch=10`; add 'glow_guide' case to `getCostForAction()` |
| `examspark_frontend/lib/core/constants/credit_history_display.dart` | Add 'glow_guide' to a filter bucket (new `filterGlowGuide` ya `filterAskAi` mein include) |
| `examspark_frontend/lib/core/constants/credit_usage_display.dart` | Add `estimateGlowGuideChats(int credits)` helper |
| `examspark_frontend/lib/presentation/screens/glow_guide/glow_guide_screen.dart` | (1) Load balance via SessionLiveSync, (2) Pre-check credits BEFORE _send / _sendSilentTurn → show Buy Credits Dialog if insufficient, (3) Read `credits_charged` + `new_balance` from result, (4) Sync balance via SessionLiveSync, (5) Show "X credits" footer on every AI assistant bubble that charged, (6) Compact cost badge on tappable chips, (7) Gender/Age chips → either confirm OR explicitly mention cost near chip OR (recommended) _sendSilentTurn ko FREE karo for metadata chips — user explicitly taps concern/question = only that costs |

## Implementation Steps (Dependency Order)

### Step 1 — Backend: Update cost constants + tests
1. Edit `glow_guide_service.py`:
   - `GLOW_GUIDE_TEXT_COST = 2` → `5`
   - `GLOW_GUIDE_PHOTO_COST = 8` → `10`
   - Docstring of `glow_guide_credit_cost()` update: "2 for text-only, 5 when a photo is attached" → "5 credits for text-only, 10 credits with a photo attached"
2. Edit `test_glow_guide_credit_cost.py`:
   - `assert glow_guide_credit_cost(False) == 2` → `== 5`
   - `assert glow_guide_credit_cost(True) == 8` → `== 10`

### Step 2 — Frontend: Shared constants + history filter
1. Edit `credit_costs.dart` (after line 68, before "Other" section):
   ```dart
   // GlowGuide (Beauty Care AI)
   static const int glowGuideText = 5;
   static const int glowGuidePhoto = 10;
   static const int glowGuideResearch = 10;
   ```
   - Update `getCostForAction()` default block: add case `'glow_guide'` → return `glowGuideText` (photo addendum server-side)
2. Edit `credit_history_display.dart`:
   - Add filter constant: `static const filterGlowGuide = 'glow_guide';`
   - Add UI label in `_categoryDetails` style for 'Glow Guide' (if used) OR simpler: include 'glow_guide' inside `filterAskAi` bucket (both are AI chat credits, logical grouping) — **Approach A (simpler, recommended):** modify `filterBucket()` to route 'glow_guide' to `filterAskAi`. **Approach B (separate):** add new chip + bucket. Pick Approach A for minimum UI churn.
3. Edit `credit_usage_display.dart` (optional, nice to have):
   - Add `static int estimateGlowGuideChats(int creditsRemaining) => creditsRemaining ~/ CreditCosts.glowGuideText;`
   - (Dashboard doesn't currently show it — keep as utility constant; no UI wiring unless explicitly needed)

### Step 3 — Frontend: GlowGuideScreen balance + pre-flight credit check
1. In `_GlowGuideScreenState`:
   - Add `void Function()? _liveSyncDispose;` + `int _creditsBalance = 0;`
   - In `initState()` after existing code, attach listener on `SessionLiveSync.instance` → setState to store `_creditsBalance = sync.creditsBalance`; call `SessionLiveSync.instance.refreshAll()` once
   - In `dispose()` → remove listener
2. Add helper `int _costFor({required bool hasPhoto}) => hasPhoto ? CreditCosts.glowGuidePhoto : CreditCosts.glowGuideText;`
3. Add helper dialog method:
   ```dart
   void _showInsufficientCreditsDialog(int needed) {
     showDialog(
       context: context,
       builder: (ctx) => AlertDialog(
         title: const Text('Not enough credits'),
         content: Text('You need at least $needed credits for Beauty Care AI. Top up to continue.'),
         actions: [
           TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
           ElevatedButton(
             onPressed: () { Navigator.pop(ctx); Navigator.pushNamed(context, '/subscription'); },
             child: const Text('Buy Credits'),
           ),
         ],
       ),
     );
   }
   ```
4. Modify `_send()` (line ~882):
   - AFTER `final image = _attachment;` → BEFORE `setState` add user bubble:
     ```dart
     final needed = _costFor(hasPhoto: image != null);
     if (_creditsBalance < needed) {
       _sending = false;
       _showInsufficientCreditsDialog(needed);
       return;
     }
     ```
5. Modify `_sendSilentTurn()` (line ~667 — Gender/Age taps):
   - **IMPORTANT DECISION:** Metadata context chips (Gender/Age) ko FREE karo → user ne abhi koi real question nahi poocha, sirf context diya. Charging 5 credits per chip tap = bad UX. 
   - To make free: pass `text: contextNote` BUT backend mein aise turns ko free mark karne ka mechanism nahi hai. Easier frontend-only **workaround for audit scope**:
     - Do NOT call `_sendSilentTurn()` on Gender/Age chips. Instead:
       - Store `_gender` / `_age` in state only
       - Pass these to next real `_send()` call via already-existing `age` field (which currently sends `'$_gender${_age != null ? ", $_age" : ""}'` anyway)
       - Result: Gender/Age = 0 credits, batched with the first real user message
   - If above "make free" approach is too invasive, ALTERNATIVE: Keep `_sendSilentTurn()` but show confirmation SnackBar: `ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('This will cost ${CreditCosts.glowGuideText} credits — Beauty Care AI will remember your selection.')))` BEFORE calling it.
   - **Plan decision: First approach (batch with next message, 0 credits for silent metadata chips) is correct UX. Implement.**

### Step 4 — Frontend: Read response credits_charged + new_balance + sync balance
1. Modify `_send()` try-block result handling (line ~924+):
   - After `final result = await ...;` → BEFORE `if (!mounted ...)`:
     ```dart
     final newBalance = result['new_balance'];
     if (newBalance is int) {
       SessionLiveSync.instance.creditsBalance = newBalance;
       SessionLiveSync.instance.notifyListeners();
       setState(() => _creditsBalance = newBalance);
     }
     final creditsCharged = result['credits_charged'] as int? ?? 0;
     ```
   - Pass `creditsCharged: creditsCharged` into the `_GlowMessage(...)` constructor (see Step 5)
2. Same pattern in `_sendSilentTurn()` result handling → after we removed Gender/Age silent calls, this method is only called ONCE on `_continueAfterCategoryChoice()` (first starter prompt after category). For that initial turn, balance refresh similarly.

### Step 5 — Frontend: Show cost badge on chips + "X credits" footer on AI bubble
1. Add `final int creditsCharged;` field to `_GlowMessage` class (default 0)
2. Chip cost badge: In the chip widget (where `ActionChip` ya `_GlowChipOption` render hota hai — inside renderTile ya _buildChipArea), add trailing small badge after each tappable chip (except free ones):
   - Widget pattern:
     ```dart
     Row(mainAxisSize: MainAxisSize.min, children: [
       Text(label),
       const SizedBox(width: 4),
       Container(
         padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
         decoration: BoxDecoration(
           color: costColor.withOpacity(0.12),
           borderRadius: BorderRadius.circular(8),
         ),
         child: Text('${cost}C', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: costColor)),
       ),
     ])
     ```
   - Which chips get a badge:
     - First screen chips (Skin / Body / Baby / Cloth / Hair) → 0 credits (just navigation) → NO badge
     - Concern chips (Acne, Hair fall, etc.) → first real message = `glowGuideText (5)` → show `· 5C`
     - Gender chips (Male / Female) → 0 credits per Step 3.5 decision → NO badge
     - Baby Age chips → 0 credits → NO badge
3. AI bubble footer (credits charged): In `renderTile` → after the AI message Markdown content (after sources if any) → add Row right-aligned:
   ```dart
   if (message.creditsCharged > 0)
     Padding(
       padding: const EdgeInsets.only(top: 8, right: 4),
       child: Align(
         alignment: Alignment.bottomRight,
         child: Text('${message.creditsCharged} credits', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.getSecondaryText(context))),
       ),
     ),
   ```
   (Matches Select AI pattern from `select_ai_result_sheet.dart:232`)

## Dependencies and Considerations
- **Backend-first order:** Update backend costs BEFORE frontend so both sides agree (otherwise FE shows 5C badge, server charges 2 → mismatch). Tests run first.
- **SessionLiveSync mutation:** Directly setting `SessionLiveSync.instance.creditsBalance = newBalance` + `notifyListeners()` is safe (it's a ValueNotifier-style ChangeNotifier) — other modules use `refreshAll()` which calls `notifyListeners()` too. No conflict.
- **_sendSilentTurn removal for Gender/Age:** Verify that `_send()` already forwards `age: _gender != null ? '$_gender${_age != null ? ", $_age" : ""}' : _age` (line 928 — yes, already present). So removing standalone `_sendSilentTurn()` calls from `_selectGender` / `_selectBabyAge` will NOT lose context.
- **Research cost (+10 credits):** Not knowable pre-flight (only server decides when Tavily runs). Pre-flight check uses base cost only. The SECONDARY insufficient-credits check still runs on backend and raises 402; we already show the error message inline. Frontend can show a generic hint near search-status: "Live web research costs +10 extra credits when used." (optional, not critical)
- **Silent initial turn (_continueAfterCategoryChoice):** This fires the first starter question. Server currently charges 5 credits. Frontend should show "5 credits" footer on that first AI bubble (consistent with actual deduction). Acceptable. User just chose a category → first AI reply = real usage.

## Validation
1. **Backend tests:** `cd examspark_backend ; python -m pytest tests/test_glow_guide_credit_cost.py -v` → both assertions pass (5, 10)
2. **Frontend lint:** `cd examspark_frontend ; flutter analyze lib/core/constants/credit_costs.dart lib/core/constants/credit_history_display.dart lib/presentation/screens/glow_guide/glow_guide_screen.dart` → no errors
3. **Manual sanity:**
   - Start app → open GlowGuide → top CreditsPill shows current balance
   - Tap "Acne / pimples" concern chip → pre-flight passes → flow works → AI bubble shows "5 credits" footer → CreditsPill balance decreases by 5
   - Set balance to 3 via profile → tap concern → AlertDialog shows → tap "Buy Credits" → navigates to /subscription
   - Upload photo → pre-flight needs 10 → balance 9 → dialog appears → correct
   - Credits history → filter chips: "Ask AI" includes GlowGuide rows; "All" still works
   - Tap "Male" gender → NO API call yet → state stores → next real message sends gender context → 1 single charge of 5 → correct

## Risks
1. **Risk: _sendSilentTurn removal breaks conversation context chain on backend**
   - Handle: Confirm that `_send()` line 928 sends `age: _gender != null ? ...` AND the backend `turn()` accepts `age:` parameter (yes, line 566 of glow_guide_service.py — `age` parameter present and line 607-608 adds to context: `if age and age.strip(): context["age"] = age.strip()`). Same for `weather` and `language`. So batching works.
2. **Risk: Race between SessionLiveSync realtime and FE direct set**
   - Handle: Same value from backend, race is idempotent. CreditsPill rebuilds twice with same value → no visual glitch.
3. **Risk: Research cost (+10) surprise post-preflight**
   - Handle: Backend already does SECONDARY check line 804-805 and raises GlowGuideError status_code 402. Frontend catch block already shows the error inline (line 989: "Beauty Care AI is unavailable right now. (Need 15 credits for GlowGuide research.)"). User sees correct message. Acceptable for scope. No plan changes required.
4. **Risk: Chip badges clutter UI on small mobile screens**
   - Handle: Badge compact ("5C"), only on concern-type chips that actually cost credits. Category/navigation chips clean. Wrap spacing. If overflow → `Wrap` widget already in use (most GlowGuide chip rows are Wrap-based), so badges will reflow naturally.
