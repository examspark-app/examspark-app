# GlowGuide Idea

## Product Vision

GlowGuide is a multilingual AI beauty and product-fit consultant. It helps users understand skin, face, makeup, lips, eyes, body, hair, baby-care, salon and fabric-related products without forcing a rigid questionnaire.

It is a product/ingredient-fit guide, not a doctor and not a salesperson.

## User-Facing Broad Categories

Keep the UI simple with five broad topic choices:

- Skin / Face
- Hair / Scalp
- Body Care
- Baby Care
- Cloth / Fabric

Do not create a separate UI category for every product type. Product types should be detected by the AI from the user's text or photo.

Current implementation note: the backend already uses the internal broad keys `skin`, `hair`, `body`, `baby`, and `cloth`. The frontend currently still contains older visible labels such as `Skin Care`, `Hair Care`, `Body Care`, `Baby Skin Care`, and `Cloth Guide` in some places. Update only the visible labels to the five labels above when doing the next UI chip patch. Keep internal keys, routes, classes, functions, and database names unchanged.

## Product Context Layer

The broad category is only the starting point. The AI must classify the actual product and usage context internally.

```text
main_category:
  skin | body | hair | baby | cloth

product_family:
  face_makeup
  lip_makeup
  eye_makeup
  skincare
  body_care
  fragrance
  hair_cleanser
  hair_conditioner
  hair_styling
  hair_color
  baby_care
  salon_chemical
  fabric_care
  other_product

application_area:
  face
  lips
  eyes
  scalp
  hair_length
  underarms
  body
  baby_skin
  fabric

usage_context:
  personal_daily
  personal_event
  bridal
  groom
  salon_client
  professional_multi_client

exposure:
  leave_on
  rinse_off
  occasional
  repeated_daily

user_or_client:
  self | client | multiple_clients
```

These fields are internal reasoning/context fields. They should not make the UI feel like a form.

## Product Coverage

The AI must keep all of these in scope:

### Skin / Face

- Face wash, cleanser, toner, serum, moisturizer, sunscreen
- Foundation, primer, concealer, BB/CC cream
- Blush, bronzer, highlighter, setting powder/spray
- Makeup remover and cleansing balm

### Lips

- Lipstick, lip gloss, lip liner, lip tint, lip balm
- Consider dryness, cracks, fragrance/flavor sensitivity and hygiene

### Eyes

- Eyeshadow, eyeliner, kajal, mascara, glitter, brow products
- Consider eye sensitivity, glitter particles, hygiene and product sharing

### Body

- Soap, body wash, body lotion, cream, scrub
- Deodorant, underarm products, body sunscreen
- Perfume, body mist, cologne and fragrance products

### Hair / Scalp

- Shampoo, scalp cleanser, anti-dandruff wash
- Conditioner, hair mask, leave-in conditioner
- Hair oil, serum, gel, wax, mousse, spray, heat protectant
- Hair dye, bleach, relaxer, rebonding, perm and straightening products

### Baby

- Baby lotion, baby wash, diaper cream, baby oil, wipes, powder
- Apply stricter fragrance-free and pediatric-safety rules

### Cloth / Fabric

- Fabric composition, garment care, detergents and textile products
- Consider breathability, sweat, sensitivity and baby clothing

## Professional and Event Use

Professional use is not a separate top-level category. It is a conditional usage context.

Detect it only from clear signals such as:

- makeup artist
- hairstylist
- salon worker
- beauty parlour
- client ke liye
- bridal makeup
- groom grooming
- multiple customers
- professional multi-client use

Daily users should not always see professional chips.

If professional/event intent is clear, use context such as:

```text
usage_context: bridal | groom | salon_client | professional_multi_client
user_or_client: client | multiple_clients
exposure: occasional
```

For a normal personal request:

```text
usage_context: personal_daily
user_or_client: self
exposure: repeated_daily
```

If intent is ambiguous, ask one short neutral question:

> Is this for your personal daily use or for a client/event?

Possible chips should be shown only in the user's current language and script:

- Personal daily use
- Personal event
- Client ke liye
- Bridal/salon use

Do not show these professional options to every daily user.

## Conversation Flow

1. User opens GlowGuide.
2. User chooses a broad topic or types freely.
3. User writes a concern, product name, ingredient list or uploads a photo.
4. AI detects the product family, application area, usage context and exposure.
5. AI checks whether the selected broad category matches the actual product.
6. If the category is wrong, AI silently switches reasoning for that turn instead of rejecting the product or sending the user back.
7. AI gives an immediate useful observation.
8. AI asks at most one high-value missing question.
9. AI gives a personalized verdict when enough information exists.
10. AI returns detailed breakdown, confidence note, practical tips, risks and research when relevant.
11. Follow-up turns preserve the active product context and language.

Examples:

```text
User selected Skin / Face + sends shampoo
=> main_category: hair
=> product_family: hair_cleanser
=> application_area: scalp
=> continue with hair rules; do not reject the product

User sends foundation for bridal client
=> main_category: skin
=> product_family: face_makeup
=> application_area: face
=> usage_context: bridal
=> user_or_client: client
=> exposure: occasional

User sends body lotion for daily use
=> main_category: body
=> product_family: body_care
=> application_area: body
=> usage_context: personal_daily
=> exposure: repeated_daily
```

## Language Rules

The existing language setup must remain unchanged.

- Hindi chat => Hindi/Devanagari
- Bengali chat => pure Bengali script
- Japanese chat => natural Japanese
- Hinglish/Banglish => same Roman style
- English chat => English
- Mixed chat => naturally mirror the user's current mix
- Chips, verdict, breakdown, tips and research labels must use the same language and script
- A short chip must not accidentally switch the active language
- New chats must carry the previous active language
- Photo responses must follow the same language lock as the conversation

Never remove or rewrite the existing language prompt engineering. Product-context rules are additive only.

## Reasoning Rules

### Surface-specific reasoning

- Face is not the same as body.
- Lips are not the same as face acne logic.
- Eyes require sensitivity and hygiene reasoning.
- Scalp is not the same as hair length.
- Conditioner is for hair length, not scalp.
- Body skin can tolerate some heavier products that may be unsuitable for facial acne-prone skin.
- Baby skin always uses a stricter safety ceiling.

### Professional/event reasoning

For bridal, groom or salon use, also consider:

- patch testing before the event
- hygiene and product sharing
- duration and long-wear exposure
- heat, sweat and removal
- client sensitivity and skin type
- chemical overlap or damaged hair
- post-event removal and aftercare

### First-response rule

The first response should be useful and fast:

- identify the product or concern
- use information already supplied
- give one immediate observation
- ask only the highest-value missing question
- do not create a long intake form
- ask for a clearer photo only when the label is genuinely unreadable

## Result Presentation

The final answer should be easy to scan:

- final verdict
- short main observation
- detailed breakdown
- confidence note
- practical tips
- what to avoid
- research sources when used
- next action/follow-up

Detailed breakdown must use short paragraphs and visible spacing. Do not pack everything into one dense box.

Do not force a kitchen remedy for:

- eyes
- lips
- makeup
- hair dye
- bleach
- relaxer
- salon chemicals

## Current Implementation Status

### Completed

- Existing multilingual language lock preserved
- Native-language chip rules added
- Product context prompt layer added
- Product family/application/usage/exposure fields added to the JSON prompt contract
- Product context persisted in GlowGuide session context
- Existing prompt tests pass
- Existing language tests pass
- Flutter custom-input regression test passes
- GlowGuide result layout spacing/open-space improvements completed

### Still Pending

- Update visible frontend broad-topic chips to exactly:
  - Skin / Face
  - Hair / Scalp
  - Body Care
  - Baby Care
  - Cloth / Fabric
- Keep internal values unchanged: `skin`, `hair`, `body`, `baby`, `cloth`
- Add focused backend tests for lipstick, eyeshadow, foundation, soap, body lotion, shampoo, conditioner, hair dye, perfume, bridal and salon-client context
- Add compatibility tests for old JSON responses where new product-context fields are absent
- Manually verify Bengali, Hindi, Japanese, Hinglish and mixed-language chip output with real model responses

## Important Constraints for the Next Agent

- Do not remove existing prompt engineering.
- Do not modify the language setup.
- Do not rename internal code identifiers.
- Do not change API routes or database table names.
- Do not create dozens of product categories in the UI.
- Do not show professional chips to every daily user.
- Do not hide unknown products; keep them in scope and ask only for the missing evidence needed.
- Make one small change at a time and run focused validation after each change.
