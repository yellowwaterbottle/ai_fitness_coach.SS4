import { GoogleGenerativeAI } from '@google/generative-ai';
import { createClient } from '@supabase/supabase-js';

// Initialize Google Gemini AI
const genAI = new GoogleGenerativeAI(process.env.GEMINI_API_KEY);

// Initialize Supabase client
const supabase = createClient(
  process.env.SUPABASE_URL,
  process.env.SUPABASE_ANON_KEY
);

const masterPrompt = `You are a professional strength and conditioning coach with an encouraging and helpful tone. Your job is to analyze raw biomechanical data from a bench press. Based on the JSON data provided below, write a short, one-paragraph coaching summary for the user. Reference their overall score and briefly explain what it means. Do not include any scores in your final output. Then, for each of the 6 metrics in the JSON, provide a short, actionable, and tailored tip that is based on the 'observed_flaw' field. The tips should be encouraging and directly connected to the metric.`;

export default async function handler(req, res) {
  // Set CORS headers
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization');

  // Handle preflight requests
  if (req.method === 'OPTIONS') {
    return res.status(200).end();
  }

  // Only allow POST requests
  if (req.method !== 'POST') {
    return res.status(405).json({ error: 'Method not allowed' });
  }

  try {
    // Extract scan_id and json_data from request body
    const { scan_id, json_data } = req.body;
    
    if (!scan_id) {
      return res.status(400).json({ error: 'Missing scan_id in request payload' });
    }
    
    if (!json_data) {
      return res.status(400).json({ error: 'Missing json_data in request payload' });
    }

    console.log('Processing coaching request for scan_id:', scan_id);

    // Initialize Gemini Pro model
    const model = genAI.getGenerativeModel({ model: 'gemini-1.5-pro' });

    // Create the prompt with the JSON data
    const prompt = `${masterPrompt}\n\nJSON Data:\n${JSON.stringify(json_data, null, 2)}`;

    // Call Gemini API
    const result = await model.generateContent(prompt);
    const response = await result.response;
    const coachingText = response.text();

    console.log('Gemini coaching response received');

    // Save the coaching output to Supabase database
    const { data, error } = await supabase
      .from('coach_output')
      .insert([
        {
          scan_id: scan_id,
          coaching_text: coachingText,
          created_at: new Date().toISOString()
        }
      ])
      .select();

    if (error) {
      console.error('Supabase insert error:', error);
      return res.status(500).json({ 
        error: 'Failed to save coaching output to database', 
        details: error.message 
      });
    }

    console.log('Coaching output saved successfully:', data);

    return res.status(200).json({
      success: true,
      message: 'Coaching analysis completed and saved successfully',
      scan_id: scan_id,
      coachingId: data[0]?.id
    });

  } catch (error) {
    console.error('Handler error:', error);
    return res.status(500).json({ 
      error: 'Internal server error', 
      details: error.message 
    });
  }
}
