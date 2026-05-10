const functions = require("firebase-functions");
const axios = require("axios");

exports.generatePlan = functions.https.onRequest(async (req, res) => {
  // دعم CORS + preflight
  res.set("Access-Control-Allow-Origin", "*");
  res.set("Access-Control-Allow-Headers", "Content-Type");

  if (req.method === "OPTIONS") {
    return res.status(204).send("");
  }

  try {
    const { income, expense, categories, planType, savings } = req.body;

    if (!income || !expense) {
      return res.status(400).json({
        success: false,
        message: "Missing required fields",
      });
    }

    const prompt = `
You are a professional financial advisor.

Income: ${income}
Expense: ${expense}
Savings: ${savings}
Categories: ${JSON.stringify(categories)}

Create a ${planType} financial plan including:
- Spending limits
- Savings strategy
- Warnings
- Action steps
- Table format output
`;

    const response = await axios.post(
      "https://api.openai.com/v1/chat/completions",
      {
        model: "gpt-4o-mini",
        messages: [
          {
            role: "system",
            content:
              "You are a strict financial advisor. Always respond in structured format.",
          },
          { role: "user", content: prompt },
        ],
        temperature: 0.7,
      },
      {
        headers: {
          Authorization: `Bearer sk-...dAYA`,
          "Content-Type": "application/json",
        },
      }
    );

    return res.json({
      success: true,
      data: response.data.choices[0].message.content,
    });

  } catch (error) {
    console.error("Function Error:", error?.response?.data || error.message);

    return res.status(500).json({
      success: false,
      error: "AI generation failed",
      details: error.message,
    });
  }
});