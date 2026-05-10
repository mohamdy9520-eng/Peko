const { setGlobalOptions } = require("firebase-functions");
const { onRequest } = require("firebase-functions/https");
const logger = require("firebase-functions/logger");
const fetch = require("node-fetch");

setGlobalOptions({ maxInstances: 10 });

exports.generatePlan = onRequest(async (req, res) => {
  try {
    const { income, expense, categories, planType, savings } = req.body;

    const prompt = `
Create a STRICT financial plan:

Income: ${income}
Expenses: ${expense}
Savings: ${savings}
Categories: ${JSON.stringify(categories)}
Plan Type: ${planType}

Provide:
1. Daily spending limit
2. Weekly checkpoints
3. Monthly saving target
4. 5 saving tips
5. Warnings for overspending

Format clearly in structured sections.
`;

    const response = await fetch("https://api.openai.com/v1/chat/completions", {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${process.env.OPENAI_API_KEY}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        model: "gpt-4o-mini",
        messages: [
          {
            role: "system",
            content: "You are a professional financial advisor.",
          },
          {
            role: "user",
            content: prompt,
          },
        ],
        temperature: 0.7,
      }),
    });

    const data = await response.json();

const result =
  data &&
  data.choices &&
  data.choices[0] &&
  data.choices[0].message &&
  data.choices[0].message.content
    ? data.choices[0].message.content
    : "No response";
    res.status(200).json({ result });
  } catch (error) {
    logger.error(error);
    res.status(500).json({ error: error.toString() });
  }
});