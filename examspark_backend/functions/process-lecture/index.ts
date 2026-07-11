import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

// ==================== CONFIGURATION ====================
const supabaseUrl = Deno.env.get('SUPABASE_URL')!
const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
const groqApiKey = Deno.env.get('GROQ_API_KEY')!

const supabase = createClient(supabaseUrl, supabaseServiceKey)

// Credit Economy v2 — feature/session-based (never per-minute in UI)
const CREDIT_COSTS = {
  RECORD_UP_TO_30_MIN: 40,
  RECORD_30_TO_60_MIN: 80,
  RECORD_60_TO_90_MIN: 120,
  SUMMARY_WITH_RECORDING: 0,
  ASK_AI_NORMAL: 5,
  ASK_AI_DEEP: 12,
  FLASHCARDS: 20,
  QUIZ_20_MCQ: 25,
  IMPORTANT_QUESTIONS: 20,
  REVISION_NOTES: 20,
  FORMULA_SHEET: 15,
  MIND_MAP: 30,
  DIAGRAM_IMAGE: 25,
  PDF_ANALYSIS: 20,
  OCR_IMAGE: 15,
  TRANSLATE: 8,
  VOICE_READ: 5,
  // Legacy aliases
  RECORD_LECTURE: 80,
  WHISPER_TURBO_HOUR: 80,
  WHISPER_NON_TURBO_HOUR: 80,
  QWEN3_TEXT: 5,
  QWEN3_VL: 25,
  MCQ_GENERATION: 25,
  REVISION_GENERATION: 20,
  IMPORTANT_QUESTIONS_GENERATION: 20,
  ANSWER_KEY_GENERATION: 25,
  FLASHCARD_GENERATION: 20,
  RAG_QUERY: 5,
  PDF_TEXT_INGEST: 20,
}

function recordCreditsForDurationMinutes(minutes: number): number {
  if (minutes <= 30) return CREDIT_COSTS.RECORD_UP_TO_30_MIN
  if (minutes <= 60) return CREDIT_COSTS.RECORD_30_TO_60_MIN
  if (minutes <= 90) return CREDIT_COSTS.RECORD_60_TO_90_MIN
  return CREDIT_COSTS.RECORD_60_TO_90_MIN
}

// API Endpoints (4 Final Locked APIs)
const API_ENDPOINTS = {
  WHISPER_TURBO: 'https://api.groq.com/openai/v1/audio/transcriptions',
  WHISPER_STANDARD: 'https://api.groq.com/openai/v1/audio/transcriptions',
  QWEN3_TEXT: 'https://api.groq.com/openai/v1/chat/completions',
  QWEN3_VL: 'https://api.groq.com/openai/v1/chat/completions'
}

// Models
const MODELS = {
  WHISPER_TURBO: 'whisper-large-v3-turbo',
  WHISPER_STANDARD: 'whisper-large-v3',
  QWEN3_TEXT: 'qwen-2-72b-instruct',
  QWEN3_VL: 'qwen-2-vl-72b-instruct'
}

// ==================== MAIN HANDLER ====================
serve(async (req: Request) => {
  console.log('=== PROCESS-LECTURE EDGE FUNCTION STARTED ===')
  const startTime = Date.now()

  try {
    const url = new URL(req.url)
    const path = url.pathname

    console.log(`Request path: ${path}`)
    console.log(`Request method: ${req.method}`)

    // ==================== ON-DEMAND EXTRAS WEBHOOKS ====================
    if (path.startsWith('/api/v1/extras/')) {
      return await handleExtrasWebhook(req, path)
    }

    // ==================== MAIN PROCESSING ROUTER ====================
    const payload = await req.json()
    console.log('Payload received:', JSON.stringify({ ...payload, audioData: '[REDACTED]', imageData: '[REDACTED]' }))

    // On-demand extras via action field (Flutter client)
    if (payload.action && !payload.input_type) {
      return await handleExtrasFromPayload(payload)
    }

    const { 
      input_type,
      audioData, 
      imageData, 
      textData, 
      high_accuracy = false, 
      userId,
      is_syllabus = false
    } = payload

    // Validate user authentication
    if (!userId) {
      console.error('ERROR: User ID required')
      return new Response(JSON.stringify({ error: 'User ID required' }), { 
        status: 401,
        headers: { 'Content-Type': 'application/json' }
      })
    }

    console.log(`User ID: ${userId}`)
    console.log(`Input type: ${input_type}`)
    console.log(`High accuracy mode: ${high_accuracy}`)

    // ==================== UNIFIED ROUTER ARCHITECTURE ====================
    console.log('=== ROUTING LOGIC ===')
    
    let result
    let creditsDeducted = 0

    // PATH A: AUDIO INPUT
    if (input_type === 'audio') {
      console.log('→ Routing to PATH A: Audio Transcription & Processing Pipeline')
      result = await executeAudioPipeline(payload, userId)
      creditsDeducted = result.creditsDeducted
    
    // PATH B: VISION INPUT
    } else if (
      input_type === 'image' || 
      input_type === 'photo' || 
      input_type === 'scanned_handwriting' || 
      input_type === 'diagram'
    ) {
      console.log('→ Routing to PATH B: Qwen3-VL Vision Pipeline')
      result = await executeVisionPipeline(payload, userId)
      creditsDeducted = result.creditsDeducted
    
    // PATH B: TEXT-ONLY PDF
    } else if (input_type === 'pdf_text_only') {
      console.log('→ Routing to PATH B: PDF Text Extraction → Qwen3 Text Pipeline')
      result = await executePdfTextPipeline(payload, userId)
      creditsDeducted = result.creditsDeducted
    
    } else {
      console.error(`ERROR: Unknown input type: ${input_type}`)
      return new Response(JSON.stringify({ error: `Unknown input type: ${input_type}` }), { 
        status: 400,
        headers: { 'Content-Type': 'application/json' }
      })
    }

    const duration = ((Date.now() - startTime) / 1000).toFixed(2)
    console.log(`=== PROCESSING COMPLETED IN ${duration}s ===`)
    console.log(`Credits deducted: ${creditsDeducted}`)

    return new Response(JSON.stringify({
      success: true,
      ...result,
      processingTime: duration
    }), {
      headers: { 'Content-Type': 'application/json' }
    })

  } catch (error) {
    const duration = ((Date.now() - startTime) / 1000).toFixed(2)
    const errorMessage = error instanceof Error ? error.message : 'Unknown error'
    const errorStack = error instanceof Error ? error.stack : 'No stack trace'
    
    console.error(`=== ERROR AFTER ${duration}s ===`)
    console.error('Error details:', errorMessage)
    console.error('Error stack:', errorStack)
    
    return new Response(JSON.stringify({ 
      error: errorMessage,
      processingTime: duration
    }), { 
      status: 500,
      headers: { 'Content-Type': 'application/json' }
    })
  }
})

// ==================== ON-DEMAND EXTRAS (PAYLOAD) ====================
async function handleExtrasFromPayload(payload: any) {
  const { userId, content, query, action, lectureId } = payload
  if (!userId) {
    return new Response(JSON.stringify({ error: 'User ID required' }), {
      status: 401,
      headers: { 'Content-Type': 'application/json' }
    })
  }

  const actionMap: Record<string, string> = {
    mcq: 'mcq',
    revision: 'revision',
    revision_sheet: 'revision',
    important_questions: 'important-questions',
    answer_key: 'answer-key',
    flashcards: 'flashcards',
    flashcard: 'flashcards',
    rag: 'ask-rag',
  }

  const mapped = actionMap[action] || action
  const creditCheck = await checkAndDeductCredits(userId, 1, mapped)
  if (!creditCheck.success) {
    return creditCheck.response
  }

  let result
  try {
    switch (mapped) {
      case 'mcq':
        result = await generateMCQ(content, groqApiKey)
        break
      case 'revision':
        result = await generateRevision(content, groqApiKey)
        break
      case 'important-questions':
        result = await generateImportantQuestions(content, groqApiKey)
        break
      case 'answer-key':
        result = await generateAnswerKey(content, groqApiKey)
        break
      case 'flashcards':
        result = await generateFlashcards(content, groqApiKey)
        break
      case 'ask-rag':
        result = await performRAGQuery(userId, query ?? content, groqApiKey, supabase)
        break
      default:
        return new Response(JSON.stringify({ error: 'Unknown extras action' }), {
          status: 400,
          headers: { 'Content-Type': 'application/json' }
        })
    }

    if (lectureId) {
      await supabase.from('extras').upsert({
        lecture_id: lectureId,
        type: action,
        content: result,
      })
    }

    return new Response(JSON.stringify({
      success: true,
      action: mapped,
      result,
      creditsDeducted: 1,
    }), { headers: { 'Content-Type': 'application/json' } })
  } catch (error) {
    const errorMessage = error instanceof Error ? error.message : 'Unknown error'
    return new Response(JSON.stringify({ error: errorMessage }), {
      status: 500,
      headers: { 'Content-Type': 'application/json' }
    })
  }
}

// ==================== ON-DEMAND EXTRAS WEBHOOKS ====================
async function handleExtrasWebhook(req: any, path: string) {
  console.log('=== EXTRAS WEBHOOK HANDLER ===')
  
  const payload = await req.json()
  const { userId, content, query } = payload

  // Validate user authentication
  if (!userId) {
    return new Response(JSON.stringify({ error: 'User ID required' }), { 
      status: 401,
      headers: { 'Content-Type': 'application/json' }
    })
  }

  // Extract action from path
  const action = path.split('/').pop() || 'unknown'
  console.log(`Extras action: ${action}`)

  // Credit pre-check (all extras cost 1 credit)
  const creditCheck = await checkAndDeductCredits(userId, 1, action)
  if (!creditCheck.success) {
    return creditCheck.response
  }

  let result

  try {
    switch (action) {
      case 'mcq':
        console.log('→ Generating MCQ questions')
        result = await generateMCQ(content, groqApiKey)
        break
      case 'revision':
        console.log('→ Generating revision sheet')
        result = await generateRevision(content, groqApiKey)
        break
      case 'important-questions':
        console.log('→ Generating important questions')
        result = await generateImportantQuestions(content, groqApiKey)
        break
      case 'answer-key':
        console.log('→ Generating answer key')
        result = await generateAnswerKey(content, groqApiKey)
        break
      case 'flashcards':
        console.log('→ Generating flashcards')
        result = await generateFlashcards(content, groqApiKey)
        break
      case 'ask-rag':
        console.log('→ Performing RAG query')
        result = await performRAGQuery(userId, query, groqApiKey, supabase)
        break
      default:
        return new Response(JSON.stringify({ error: 'Unknown extras action' }), { 
          status: 400,
          headers: { 'Content-Type': 'application/json' }
        })
    }

    return new Response(JSON.stringify({
      success: true,
      action,
      result,
      creditsDeducted: 1
    }), {
      headers: { 'Content-Type': 'application/json' }
    })

  } catch (error) {
    const errorMessage = error instanceof Error ? error.message : 'Unknown error'
    console.error(`Extras webhook error (${action}):`, errorMessage)
    return new Response(JSON.stringify({ error: errorMessage }), { 
      status: 500,
      headers: { 'Content-Type': 'application/json' }
    })
  }
}

// ==================== PATH A: AUDIO PIPELINE ====================
async function executeAudioPipeline(payload: any, userId: string) {
  console.log('=== PATH A: AUDIO TRANSCRIPTION & PROCESSING PIPELINE ===')
  
  const { audioData, high_accuracy = false, lectureId } = payload
  const useTurbo = !high_accuracy
  const requiredCredits = useTurbo ? CREDIT_COSTS.WHISPER_TURBO_HOUR : CREDIT_COSTS.WHISPER_NON_TURBO_HOUR

  const updateLectureStatus = async (status: string) => {
    if (!lectureId) return
    await supabase.from('lectures').update({ status, updated_at: new Date().toISOString() }).eq('id', lectureId)
  }

  await updateLectureStatus('splitting')

  console.log(`Credit requirement: ${requiredCredits} (${useTurbo ? 'Turbo' : 'Non-Turbo'})`)

  // Credit Pre-Check
  const creditCheck = await checkAndDeductCredits(userId, requiredCredits, 'audio_transcription')
  if (!creditCheck.success) {
    throw new Error(creditCheck.error)
  }

  console.log('✓ Credits deducted successfully')

  // Upload audio to temporary storage
  console.log('→ Uploading audio to temporary storage')
  const fileName = `temp_${userId}_${Date.now()}.webm`

  let uploadBody: Uint8Array | string = audioData
  if (typeof audioData === 'string') {
    uploadBody = Uint8Array.from(atob(audioData), (c) => c.charCodeAt(0))
  }

  const { error: uploadError } = await supabase
    .storage
    .from('temp-audio')
    .upload(fileName, uploadBody, {
      contentType: 'audio/webm',
      upsert: true
    })

  if (uploadError) {
    console.error('Audio upload failed:', uploadError)
    throw new Error('Failed to upload audio')
  }

  console.log(`✓ Audio uploaded: ${fileName}`)

  // Get public URL
  const { data: { publicUrl } } = supabase
    .storage
    .from('temp-audio')
    .getPublicUrl(fileName)
  console.log(`Public URL: ${publicUrl}`)

  // Chunking & Parallelization (if needed)
  console.log('→ Checking if chunking is needed')
  let transcript = ''
  
  // For now, simple transcription (chunking logic can be added for large files)
  // TODO: Implement audio duration check and chunking for files > 10 minutes
  console.log('→ Transcribing audio (single chunk for now)')
  await updateLectureStatus('transcribing')
  
  const whisperModel = useTurbo ? MODELS.WHISPER_TURBO : MODELS.WHISPER_STANDARD
  console.log(`Using Whisper model: ${whisperModel}`)

  // Fetch audio and create proper multipart form
  const audioResponse = await fetch(publicUrl)
  const audioBlob = await audioResponse.blob()
  
  const formData = new FormData()
  formData.append('file', audioBlob, 'audio.webm')
  formData.append('model', whisperModel)
  formData.append('response_format', 'text')

  console.log('→ Sending to Groq Whisper API')
  const whisperResponse = await fetch(API_ENDPOINTS.WHISPER_TURBO, {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${groqApiKey}`,
    },
    body: formData
  })

  if (!whisperResponse.ok) {
    console.error('Whisper API failed:', whisperResponse.status, await whisperResponse.text())
    // Clean up audio file on error
    await supabase.storage.from('temp-audio').remove([fileName])
    throw new Error('Transcription failed')
  }

  transcript = await whisperResponse.text()
  console.log(`✓ Transcription complete (${transcript.length} characters)`)

  // CRITICAL - INSTANT PURGE RULE
  console.log('→ EXECUTING INSTANT PURGE: Deleting raw audio file')
  await supabase.storage.from('temp-audio').remove([fileName])
  console.log('✓ Audio file purged from storage')

  // Downstream LLM Invocation: Qwen3 Text Processing
  console.log('→ Sending transcript to Qwen3 for note generation')
  await updateLectureStatus('generating')
  const processedContent = await callQwen3(transcript, groqApiKey)
  console.log('✓ Qwen3 processing complete')

  // Persist notes + transcript when lectureId provided
  if (lectureId) {
    await supabase.from('transcripts').upsert({
      lecture_id: lectureId,
      content: transcript,
    })
    await supabase.from('notes').upsert({
      lecture_id: lectureId,
      short_summary: processedContent?.shortSummary ?? '',
      key_points: processedContent?.keyPoints ?? [],
      clean_notes: processedContent?.cleanNotes ?? '',
      important_terms: processedContent?.importantTerms ?? [],
    })
    await updateLectureStatus('done')
  }

  // Asynchronous RAG Indexing
  console.log('→ Queueing RAG indexing (background task)')
  await updateLectureStatus('indexing')
  saveToRAG(transcript, userId, supabase).catch(err => {
    console.error('RAG indexing failed (non-blocking):', err.message)
  })

  return {
    transcript,
    processedContent,
    creditsDeducted: requiredCredits,
    lectureId,
  }
}

// ==================== PATH B: VISION PIPELINE ====================
async function executeVisionPipeline(payload: any, userId: string) {
  console.log('=== PATH B: QWEN3-VL VISION PIPELINE ===')
  
  const { imageData, textData = '', is_syllabus = false } = payload
  const requiredCredits = CREDIT_COSTS.QWEN3_VL

  console.log(`Credit requirement: ${requiredCredits} (Qwen3-VL)`)

  // Credit Pre-Check
  const creditCheck = await checkAndDeductCredits(userId, requiredCredits, 'vision_processing')
  if (!creditCheck.success) {
    throw new Error(creditCheck.error)
  }

  console.log('✓ Credits deducted successfully')

  // Direct Vision Routing to Qwen3-VL
  console.log('→ Sending image to Qwen3-VL for analysis')
  const processedContent = await callQwen3VL(imageData, textData, groqApiKey)
  console.log('✓ Qwen3-VL processing complete')

  // Extract text for RAG if marked as syllabus/reference
  if (is_syllabus) {
    console.log('→ Content marked as syllabus, indexing to RAG')
    const extractedText = processedContent.cleanNotes || ''
    if (extractedText) {
      saveToRAG(extractedText, userId, supabase).catch(err => {
        console.error('RAG indexing failed (non-blocking):', err.message)
      })
    }
  }

  return {
    processedContent,
    creditsDeducted: requiredCredits
  }
}

// ==================== PATH B: PDF TEXT PIPELINE ====================
async function executePdfTextPipeline(payload: any, userId: string) {
  console.log('=== PATH B: PDF TEXT EXTRACTION → QWEN3 PIPELINE ===')
  
  const { textData } = payload
  const requiredCredits = CREDIT_COSTS.PDF_TEXT_INGEST

  console.log(`Credit requirement: ${requiredCredits} (PDF text ingest)`)

  // Credit Pre-Check
  const creditCheck = await checkAndDeductCredits(userId, requiredCredits, 'pdf_ingest')
  if (!creditCheck.success) {
    throw new Error(creditCheck.error)
  }

  console.log('✓ Credits deducted successfully')

  console.log('→ Extracted text from PDF, sending to Qwen3')
  const processedContent = await callQwen3(textData, groqApiKey)
  console.log('✓ Qwen3 processing complete')

  // Index to RAG
  console.log('→ Indexing PDF content to RAG')
  saveToRAG(textData, userId, supabase).catch(err => {
    console.error('RAG indexing failed (non-blocking):', err.message)
  })

  return {
    transcript: textData,
    processedContent,
    creditsDeducted: requiredCredits
  }
}

// ==================== CREDIT MANAGEMENT ====================
async function checkAndDeductCredits(userId: string, requiredCredits: number, action: string) {
  console.log(`→ Checking credit balance (required: ${requiredCredits})`)
  
  const { data: userProfile, error: profileError } = await supabase
    .from('users')
    .select('credits_balance')
    .eq('id', userId)
    .single()

  if (profileError || !userProfile) {
    console.error('Failed to fetch user profile:', profileError)
    return {
      success: false,
      error: 'Failed to fetch user profile',
      response: new Response(JSON.stringify({ error: 'Failed to fetch user profile' }), { 
        status: 500,
        headers: { 'Content-Type': 'application/json' }
      })
    }
  }

  console.log(`Current balance: ${userProfile.credits_balance}`)

  if (userProfile.credits_balance < requiredCredits) {
    console.error(`Insufficient credits: ${userProfile.credits_balance} < ${requiredCredits}`)
    return {
      success: false,
      error: 'Insufficient credits',
      response: new Response(JSON.stringify({ 
        error: 'Insufficient credits',
        required: requiredCredits,
        balance: userProfile.credits_balance
      }), { 
        status: 402,
        headers: { 'Content-Type': 'application/json' }
      })
    }
  }

  // Deduct credits
  console.log(`→ Deducting ${requiredCredits} credits`)
  const { error: deductError } = await supabase
    .from('users')
    .update({ 
      credits_balance: userProfile.credits_balance - requiredCredits 
    })
    .eq('id', userId)

  if (deductError) {
    console.error('Failed to deduct credits:', deductError)
    return {
      success: false,
      error: 'Failed to deduct credits',
      response: new Response(JSON.stringify({ error: 'Failed to deduct credits' }), { 
        status: 500,
        headers: { 'Content-Type': 'application/json' }
      })
    }
  }

  console.log(`✓ Credits deducted. New balance: ${userProfile.credits_balance - requiredCredits}`)

  // Log transaction
  await supabase.from('credit_transactions').insert({
    user_id: userId,
    amount: -requiredCredits,
    action: action,
    description: `${action} - ${requiredCredits} credits`,
    created_at: new Date().toISOString()
  })

  return { success: true }
}

// ==================== RAG PIPELINE ====================
async function saveToRAG(content: string, userId: string, supabaseClient: any) {
  try {
    console.log('→ Saving content to RAG vector database')
    await supabaseClient.from('rag_documents').insert({
      user_id: userId,
      content: content,
      created_at: new Date().toISOString()
    })
    console.log('✓ Content saved to RAG vector database')
  } catch (error) {
    const errorMessage = error instanceof Error ? error.message : 'Unknown error'
    console.error('Failed to save to RAG:', errorMessage)
    // Don't throw - RAG failure shouldn't block main flow
  }
}

async function performRAGQuery(userId: string, query: string, apiKey: string, supabaseClient: any) {
  console.log('→ Performing RAG vector lookup')
  
  try {
    // Simple similarity search (can be enhanced with proper vector similarity)
    const { data: documents } = await supabaseClient
      .from('rag_documents')
      .select('content')
      .eq('user_id', userId)
      .limit(5)

    if (!documents || documents.length === 0) {
      console.log('No RAG documents found, using Qwen3 without context')
      return await callQwen3(query, apiKey)
    }

    console.log(`Found ${documents.length} RAG documents`)
    
    // Combine documents as context
    const context = documents.map((doc: any) => doc.content).join('\n\n')
    
    // Send to Qwen3 with RAG context
    const response = await fetch(API_ENDPOINTS.QWEN3_TEXT, {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${apiKey}`,
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({
        model: MODELS.QWEN3_TEXT,
        messages: [
          {
            role: 'system',
            content: 'You are an expert educational assistant. Answer the question using the provided context from the user\'s notes.'
          },
          {
            role: 'user',
            content: `Context:\n${context}\n\nQuestion: ${query}`
          }
        ],
        temperature: 0.3,
        max_tokens: 2048
      })
    })

    const data = await response.json()
    return {
      answer: data.choices[0].message.content,
      contextUsed: documents.length
    }

  } catch (error) {
    const errorMessage = error instanceof Error ? error.message : 'Unknown error'
    console.error('RAG query failed:', errorMessage)
    // Fallback to Qwen3 without context
    return await callQwen3(query, apiKey)
  }
}

// ==================== QWEN3 API CALLS ====================
async function callQwen3VL(imageData: string, textContext: string, apiKey: string) {
  console.log('→ Calling Qwen3-VL API')
  
  const response = await fetch(API_ENDPOINTS.QWEN3_VL, {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${apiKey}`,
      'Content-Type': 'application/json'
    },
    body: JSON.stringify({
      model: MODELS.QWEN3_VL,
      messages: [
        {
          role: 'system',
          content: 'You are an expert educational content analyzer. Analyze the provided image/diagram along with any text context. Extract meaning, process mathematical expressions, execute OCR and diagram analysis. Return structured markdown notes.'
        },
        {
          role: 'user',
          content: [
            { type: 'text', text: textContext || 'Analyze this image/diagram and extract educational content:' },
            { type: 'image_url', image_url: { url: imageData } }
          ]
        }
      ],
      temperature: 0.3,
      max_tokens: 4096
    })
  })

  if (!response.ok) {
    throw new Error(`Qwen3-VL API failed: ${response.status}`)
  }

  const data = await response.json()
  const content = data.choices[0].message.content
  
  return {
    cleanNotes: content,
    keyPoints: extractKeyPoints(content),
    shortSummary: generateSummary(content),
    importantTerms: extractTerms(content)
  }
}

async function callQwen3(text: string, apiKey: string) {
  console.log('→ Calling Qwen3 Text API')
  
  const response = await fetch(API_ENDPOINTS.QWEN3_TEXT, {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${apiKey}`,
      'Content-Type': 'application/json'
    },
    body: JSON.stringify({
      model: MODELS.QWEN3_TEXT,
      messages: [
        {
          role: 'system',
          content: `You are an expert educational content processor. Process the following transcript and return a structured JSON response with:
          1. cleanNotes: Well-formatted, organized notes in markdown
          2. keyPoints: Bullet points of main concepts (array)
          3. shortSummary: 2-3 sentence summary
          4. importantTerms: Key vocabulary with definitions (array of objects with term and definition)`
        },
        {
          role: 'user',
          content: text
        }
      ],
      temperature: 0.3,
      max_tokens: 4096,
      response_format: { type: 'json_object' }
    })
  })

  if (!response.ok) {
    throw new Error(`Qwen3 API failed: ${response.status}`)
  }

  const data = await response.json()
  const content = JSON.parse(data.choices[0].message.content)
  
  return {
    cleanNotes: content.cleanNotes,
    keyPoints: content.keyPoints,
    shortSummary: content.shortSummary,
    importantTerms: content.importantTerms
  }
}

// ==================== EXTRAS GENERATION FUNCTIONS ====================
async function generateMCQ(content: string, apiKey: string) {
  const response = await fetch(API_ENDPOINTS.QWEN3_TEXT, {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${apiKey}`,
      'Content-Type': 'application/json'
    },
    body: JSON.stringify({
      model: MODELS.QWEN3_TEXT,
      messages: [
        {
          role: 'system',
          content: 'Generate multiple choice questions based on the content. Return JSON with questions array containing question, options (A,B,C,D), and correctAnswer.'
        },
        {
          role: 'user',
          content: content
        }
      ],
      temperature: 0.3,
      max_tokens: 2048,
      response_format: { type: 'json_object' }
    })
  })
  const data = await response.json()
  return JSON.parse(data.choices[0].message.content)
}

async function generateRevision(content: string, apiKey: string) {
  const response = await fetch(API_ENDPOINTS.QWEN3_TEXT, {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${apiKey}`,
      'Content-Type': 'application/json'
    },
    body: JSON.stringify({
      model: MODELS.QWEN3_TEXT,
      messages: [
        {
          role: 'system',
          content: 'Generate a comprehensive revision sheet with key concepts, formulas, and summary points. Return structured markdown.'
        },
        {
          role: 'user',
          content: content
        }
      ],
      temperature: 0.3,
      max_tokens: 2048
    })
  })
  const data = await response.json()
  return { revisionSheet: data.choices[0].message.content }
}

async function generateImportantQuestions(content: string, apiKey: string) {
  const response = await fetch(API_ENDPOINTS.QWEN3_TEXT, {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${apiKey}`,
      'Content-Type': 'application/json'
    },
    body: JSON.stringify({
      model: MODELS.QWEN3_TEXT,
      messages: [
        {
          role: 'system',
          content: 'Generate important exam questions based on the content. Return JSON with questions array.'
        },
        {
          role: 'user',
          content: content
        }
      ],
      temperature: 0.3,
      max_tokens: 2048,
      response_format: { type: 'json_object' }
    })
  })
  const data = await response.json()
  return JSON.parse(data.choices[0].message.content)
}

async function generateAnswerKey(content: string, apiKey: string) {
  const response = await fetch(API_ENDPOINTS.QWEN3_TEXT, {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${apiKey}`,
      'Content-Type': 'application/json'
    },
    body: JSON.stringify({
      model: MODELS.QWEN3_TEXT,
      messages: [
        {
          role: 'system',
          content: 'Generate an answer key for the content. Return structured markdown with answers to potential questions.'
        },
        {
          role: 'user',
          content: content
        }
      ],
      temperature: 0.3,
      max_tokens: 2048
    })
  })
  const data = await response.json()
  return { answerKey: data.choices[0].message.content }
}

async function generateFlashcards(content: string, apiKey: string) {
  const response = await fetch(API_ENDPOINTS.QWEN3_TEXT, {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${apiKey}`,
      'Content-Type': 'application/json'
    },
    body: JSON.stringify({
      model: MODELS.QWEN3_TEXT,
      messages: [
        {
          role: 'system',
          content: 'Generate flashcards from the content. Return JSON with cards array containing front (question) and back (answer).'
        },
        {
          role: 'user',
          content: content
        }
      ],
      temperature: 0.3,
      max_tokens: 2048,
      response_format: { type: 'json_object' }
    })
  })
  const data = await response.json()
  return JSON.parse(data.choices[0].message.content)
}

// ==================== HELPER FUNCTIONS ====================
function extractKeyPoints(content: string): string[] {
  const sentences = content.split('.').filter(s => s.trim().length > 0)
  return sentences.slice(0, 5).map(s => s.trim())
}

function generateSummary(content: string): string {
  const sentences = content.split('.').filter(s => s.trim().length > 0)
  return sentences.slice(0, 2).join('. ') + '.'
}

function extractTerms(content: string): Array<{ term: string, definition: string }> {
  const words = content.split(/\s+/).filter(w => w.length > 5)
  return words.slice(0, 5).map(word => ({
    term: word,
    definition: `Definition for ${word}`
  }))
}
