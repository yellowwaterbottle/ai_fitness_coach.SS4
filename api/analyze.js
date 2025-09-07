import { GoogleGenerativeAI } from '@google/generative-ai';
import { createClient } from '@supabase/supabase-js';
import axios from 'axios';

// Initialize Google Gemini AI
const genAI = new GoogleGenerativeAI(process.env.GEMINI_API_KEY);

// Initialize Supabase client
const supabase = createClient(
  process.env.SUPABASE_URL,
  process.env.SUPABASE_ANON_KEY
);

const masterPrompt = `You are an expert biomechanist and strength and conditioning coach specializing in the bench press. Your task is to analyze the user's bench press video and provide a precise, data-driven assessment.

Instructions:
First, analyze the visual context of the video. Describe the lifter's body position, the environment (e.g., gym, home), and the camera angle. Identify any visual obstructions or poor lighting that might affect the analysis.
Then, perform a biomechanical analysis of the user's form for a barbell bench press.
Do not include any conversational text or summary outside of the final JSON object.
Output only a single JSON object that strictly adheres to the schema provided below.
If a metric is not visible, provide a score of 0 and note N/A for the flaw and recommendation.

JSON Schema:
{
  "context": {
    "type": "object",
    "description": "A brief analysis of the video's visual context.",
    "properties": {
      "camera_angle": {
        "type": "string",
        "description": "The camera's perspective (e.g., side view, front view, etc.)."
      },
      "environment": {
        "type": "string",
        "description": "A short description of the environment (e.g., commercial gym, home gym)."
      },
      "visual_issues": {
        "type": "string",
        "description": "Any visual issues that might affect the analysis (e.g., poor lighting, obstructions)."
      }
    }
  },
  "overall_score": {
    "type": "integer",
    "description": "A single score out of 100 representing the overall quality of the bench press form. A score below 70 indicates critical errors."
  },
  "metrics": {
    "type": "array",
    "description": "An array of 6 objects, each representing a key metric of bench press form.",
    "items": {
      "type": "object",
      "properties": {
        "name": {
          "type": "string",
          "enum": ["Scapular Retraction", "Bar Path", "Elbow Position", "Range of Motion", "Wrist Alignment", "Leg Drive"]
        },
        "score": {
          "type": "integer",
          "description": "A score from 0 to 100 for this specific metric."
        },
        "observed_flaw": {
          "type": "string",
          "description": "A brief, specific description of the form flaw observed in the video for this metric. If there is no flaw, describe the good form."
        },
        "recommendation": {
          "type": "string",
          "description": "A concise, actionable coaching tip to improve this metric, based directly on the observed flaw."
        }
      },
      "required": ["name", "score", "observed_flaw", "recommendation"]
    }
  }
}`;

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
    // Extract video URL from Supabase webhook payload
    const { record } = req.body;
    
    if (!record || !record.url) {
      return res.status(400).json({ error: 'No video URL found in webhook payload' });
    }

    const videoUrl = record.url;
    console.log('Processing video:', videoUrl);

    // Initialize Gemini Pro Vision model
    const model = genAI.getGenerativeModel({ model: 'gemini-1.5-pro' });

    // Create the prompt with video URL
    const prompt = `${masterPrompt}\n\nPlease analyze this video: ${videoUrl}`;

    // Call Gemini API
    const result = await model.generateContent(prompt);
    const response = await result.response;
    const text = response.text();

    console.log('Gemini response received');

    // Extract JSON from response (remove any markdown formatting)
    let jsonText = text.trim();
    if (jsonText.startsWith('```json')) {
      jsonText = jsonText.replace(/^```json\s*/, '').replace(/\s*```$/, '');
    } else if (jsonText.startsWith('```')) {
      jsonText = jsonText.replace(/^```\s*/, '').replace(/\s*```$/, '');
    }

    // Parse the JSON response
    let analysisData;
    try {
      analysisData = JSON.parse(jsonText);
    } catch (parseError) {
      console.error('Failed to parse Gemini response as JSON:', parseError);
      console.error('Raw response:', text);
      return res.status(500).json({ 
        error: 'Failed to parse AI response', 
        details: parseError.message 
      });
    }

    // Validate the required structure
    if (!analysisData.overall_score || !analysisData.metrics || !analysisData.context) {
      return res.status(500).json({ 
        error: 'Invalid analysis data structure from AI' 
      });
    }

    // Validate metrics structure
    if (!Array.isArray(analysisData.metrics) || analysisData.metrics.length !== 6) {
      return res.status(500).json({ 
        error: 'Invalid metrics array structure from AI' 
      });
    }

    // Validate each metric has required fields
    const requiredFields = ['name', 'score', 'observed_flaw', 'recommendation'];
    for (const metric of analysisData.metrics) {
      for (const field of requiredFields) {
        if (!(field in metric)) {
          return res.status(500).json({ 
            error: `Missing required field '${field}' in metrics` 
          });
        }
      }
    }

    // Save to Supabase database
    const { data, error } = await supabase
      .from('form_scans')
      .insert([
        {
          video_url: videoUrl,
          analysis_data: analysisData,
          created_at: new Date().toISOString()
        }
      ])
      .select();

    if (error) {
      console.error('Supabase insert error:', error);
      return res.status(500).json({ 
        error: 'Failed to save analysis to database', 
        details: error.message 
      });
    }

    console.log('Analysis saved successfully:', data);

    return res.status(200).json({
      success: true,
      message: 'Video analysis completed and saved successfully',
      analysisId: data[0]?.id
    });

  } catch (error) {
    console.error('Handler error:', error);
    return res.status(500).json({ 
      error: 'Internal server error', 
      details: error.message 
    });
  }
}