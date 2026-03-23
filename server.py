from fastapi import FastAPI
from pydantic import BaseModel
import os
import uvicorn
import re
import base64
import edge_tts
import asyncio
import httpx
from fastapi.middleware.cors import CORSMiddleware
from openai import OpenAI

app = FastAPI()

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Chave do Groq fornecida (gsk_...)
GROQ_API_KEY = "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"

# Usando o Groq (100% gratuito no limite do plano deles e extremamente rápido)
client = OpenAI(
    base_url="https://api.groq.com/openai/v1",
    api_key=GROQ_API_KEY,
)

# Modelo Llama 3.3 no Groq: Eficiente e gratuito
MODEL_NAME = "llama-3.3-70b-versatile"

class Query(BaseModel):
    text: str
    is_agent: bool = False

# Mapeamento para TradingView (Símbolos)
TV_SYMBOLS = {
    "bitcoin": "BINANCE:BTCUSDT", "btc": "BINANCE:BTCUSDT",
    "ethereum": "BINANCE:ETHUSDT", "eth": "BINANCE:ETHUSDT",
    "solana": "BINANCE:SOLUSDT", "sol": "BINANCE:SOLUSDT",
    "binance": "BINANCE:BNBUSDT", "bnb": "BINANCE:BNBUSDT"
}

COIN_MAP = {
    "bitcoin": "bitcoin", "btc": "bitcoin",
    "ethereum": "ethereum", "eth": "ethereum",
    "solana": "solana", "sol": "solana",
    "binance": "binancecoin", "bnb": "binancecoin"
}

async def get_market_data(text: str):
    found_data = []
    text_lower = text.lower()
    async with httpx.AsyncClient() as http_client:
        for name, coin_id in COIN_MAP.items():
            if name in text_lower:
                try:
                    url = f"https://api.coingecko.com/api/v3/coins/{coin_id}?localization=false&tickers=false&market_data=true&community_data=false&developer_data=false&sparkline=false"
                    response = await http_client.get(url, timeout=10.0)
                    if response.status_code == 200:
                        data = response.json()
                        m_data = data.get("market_data", {})
                        price = m_data.get("current_price", {}).get("usd")
                        high_24h = m_data.get("high_24h", {}).get("usd")
                        low_24h = m_data.get("low_24h", {}).get("usd")
                        sentiment_up = data.get("sentiment_votes_up_percentage", 50)

                        if price is not None:
                            info = (
                                f"Ativo: {name.upper()}. Preço: ${price:,.2f} USD. "
                                f"Máxima 24h: ${high_24h:,.2f}. Mínima 24h: ${low_24h:,.2f}. "
                                f"Sentimento: {sentiment_up}% Otimista."
                            )
                            found_data.append(info)
                except Exception: pass
    return " | ".join(found_data) if found_data else "Dados indisponíveis."

async def generate_voice_base64(text: str, is_agent: bool):
    try:
        voice = "pt-BR-AntonioNeural" if is_agent else "pt-BR-FranciscaNeural"
        communicate = edge_tts.Communicate(text, voice)
        audio_data = b""
        async for chunk in communicate.stream():
            if chunk["type"] == "audio":
                audio_data += chunk["data"]
        return base64.b64encode(audio_data).decode('utf-8')
    except:
        return None

@app.post('/query')
async def query(q: Query):
    try:
        market_context = await get_market_data(q.text)
        chart_symbol = None
        interval = "60"
        text_lower = q.text.lower()
        for name, symbol in TV_SYMBOLS.items():
            if name in text_lower:
                chart_symbol = symbol
                break

        if "15" in text_lower: interval = "15"
        elif "4" in text_lower and "hora" in text_lower: interval = "240"
        elif "1" in text_lower and "dia" in text_lower: interval = "D"

        # PivotPointsStandard para ALVOS (R1, R2, S1, S2)
        indicators_list = [
            "BB@tv-basicstudies",
            "SuperTrend@tv-basicstudies",
            "PivotPointsStandard@tv-basicstudies"
        ]

        if q.is_agent:
            persona = (
                "Você é o Bee, analista trader da TerlineT. Comece com 'Bee informando: '. "
                "Sua missão é projetar ALVOS de preço. "
                "Explique que as linhas horizontais R1 e R2 no gráfico são os alvos de alta (resistência), "
                "e as linhas S1 e S2 são os suportes de baixa (onde o preço pode cair)."
            )
        else:
            persona = "Você é a TerlineT, uma IA informativa."

        system_instruction = f"{persona}\n\nCONTEXTO DO MERCADO: {market_context}\n\nResponda em português, sem emojis."

        messages = [{"role": "system", "content": system_instruction}, {"role": "user", "content": q.text}]

        # Chamada da API Groq
        completion = client.chat.completions.create(
            model=MODEL_NAME,
            messages=messages,
            max_tokens=500
        )

        text_response = completion.choices[0].message.content.strip()
        clean_text = re.sub(r'[^\w\s,.?!áàâãéèêíïóôõöúçÁÀÂÃÉÈÊÍÏÓÔÕÖÚÇ-]', '', text_response)

        audio_base64 = await generate_voice_base64(clean_text, q.is_agent)
        show_chart = any(word in text_lower for word in ["gráfico", "grafico", "análise", "analise", "preço", "tendência", "alvo"])

        return {
            "text": clean_text,
            "audio": audio_base64,
            "chart_symbol": chart_symbol if (chart_symbol and show_chart) else None,
            "interval": interval,
            "indicators": "|".join(indicators_list),
            "show_tools": True
        }
    except Exception as e:
        return {"text": f"Bee informando: Erro de API ({str(e)}).", "audio": None}

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=7860)
