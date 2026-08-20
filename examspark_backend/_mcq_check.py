from app.services import english_practice_service as eps

sp = eps._system_prompt('Hindi', 'grammar', memory_context='', target_language='English')
assert 'OPTIONAL PRACTICE MCQ BLOCK' in sp
assert 'WHEN TO INCLUDE IT' in sp
assert 'MCQ LANGUAGE RULES — READ EVERY TIME' in sp
assert 'student' in sp and 'OWN native' in sp
assert 'correct_option MUST be an integer index' in sp
print('system_prompt includes MCQ instruction block OK')

text = """Great question! The past simple of go is went.
<<PRACTICE_MCQ>>
{
  "question": "Choose the past tense of go",
  "options": ["goed", "went", "gone"],
  "correct_option": 1
}
<<END_PRACTICE_MCQ>>
"""
clean, mcq = eps._extract_mcq(text)
assert mcq is not None, 'MCQ not parsed'
assert mcq['correct_option'] == 1
assert mcq['options'] == ['goed', 'went', 'gone']
assert 'PRACTICE_MCQ' not in clean
assert mcq['question'] == 'Choose the past tense of go'
print(f'Parser OK: extracted mcq={mcq}')

clean_no, mcq_no = eps._extract_mcq('Just a normal reply, no markers here.')
assert mcq_no is None
assert clean_no == 'Just a normal reply, no markers here.'
print('No-marker case OK: mcq is None, text unchanged')

bad = """<<PRACTICE_MCQ>>
not json at all
<<END_PRACTICE_MCQ>>"""
c, m = eps._extract_mcq(bad)
assert m is None
assert 'not json' not in c
print('Bad JSON case OK: mcq None, markers stripped')

# Test combined with suggestions:
combined = """Nice try! The correct answer is B.
<<SUGGESTIONS>>Next question|Review grammar|Try again<<END_SUGGESTIONS>>
<<PRACTICE_MCQ>>
{"question":"Q","options":["a","b","c"],"correct_option":2}
<<END_PRACTICE_MCQ>>
"""
c1, s1 = eps._extract_suggestions(combined)
c2, m1 = eps._extract_mcq(c1)
assert s1 == ['Next question', 'Review grammar', 'Try again'], f's1={s1}'
assert m1 is not None and m1['correct_option'] == 2, f'm1={m1}'
assert 'PRACTICE_MCQ' not in c2 and 'SUGGESTIONS' not in c2
print('Combined suggestions+mcq extraction OK')

print()
print('=== ALL BACKEND CHECKS PASSED ===')
