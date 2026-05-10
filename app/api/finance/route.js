const OPENAI_API_KEY = process.env.OPENAI_API_KEY;

export async function POST(req) {
  try {
    if (!OPENAI_API_KEY) {
      return Response.json(
        {
          error: "OPENAI_API_KEY is missing",
        },
        {
          status: 500,
        },
      );
    }

    const body = await req.json();

    const {
      income,
      expense,
      categories,
      planType,
      savings,
      prompt,
    } = body;

    if (
      income == null ||
      expense == null ||
      !categories ||
      !planType ||
      savings == null
    ) {
      return Response.json(
        {
          error: "Missing required fields",
        },
        {
          status: 400,
        },
      );
    }

    const aiResponse = await fetch(
      "https://api.openai.com/v1/chat/completions",
      {
        method: "POST",
        headers: {
          Authorization: `Bearer ${OPENAI_API_KEY}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          model: "gpt-4o-mini",
          temperature: 0.7,
          messages: [
            {
              role: "system",
              content:
                "You are a professional financial advisor. Return clear, structured financial plans.",
            },
            {
              role: "user",
              content: prompt,
            },
          ],
        }),
      },
    );

    if (!aiResponse.ok) {
      const errorText = await aiResponse.text();

      return Response.json(
        {
          error: errorText,
        },
        {
          status: aiResponse.status,
        },
      );
    }

    const result = await aiResponse.json();

    return Response.json(result);
  } catch (error) {
    return Response.json(
      {
        error: error.message,
      },
      {
        status: 500,
      },
    );
  }
}