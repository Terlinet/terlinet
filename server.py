from fastapi import FastAPI
from pydantic import BaseModel
import os
import uvicorn
import re
import base64
import edge_tts
import asyncio
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

HF_TOKEN = os.getenv("HF_TOKEN") 

client = OpenAI(
    base_url="https://router.huggingface.co/v1",
    api_key=HF_TOKEN,
)

MODEL_NAME = "deepseek-ai/DeepSeek-R1:novita"

class Query(BaseModel):
    text: str

async def generate_voice_base64(text: str):
    # Voz feminina brasileira realista (Microsoft Francisca Online)
    voice = "pt-BR-FranciscaNeural"
    communicate = edge_tts.Communicate(text, voice)
    audio_data = b""
    async for chunk in communicate.stream():
        if chunk["type"] == "audio":
            audio_data += chunk["data"]
    
    return base64.b64encode(audio_data).decode('utf-8')

@app.post('/query')
async def query(q: Query):
    try:
        system_instruction = (
            "Sua identidade é TerlineT. Você foi criado pela TerlineT. "
            "Nunca mencione DeepSeek, OpenAI ou qualquer outra empresa. "
            "Responda sempre em português, de forma amigável, curta e SEM EMOJIS."
        )

        messages = [
            {"role": "system", "content": system_instruction},
            {"role": "user", "content": q.text}
        ]
        
        completion = client.chat.completions.create(
            model=MODEL_NAME,
            messages=messages,
            max_tokens=512,
            temperature=0.4,
        )
        
        text_response = completion.choices[0].message.content.strip()
        
        # Limpeza do texto para o TTS
        clean_text = re.sub(r'[^\w\s,.?!áàâãéèêíïóôõöúçÁÀÂÃÉÈÊÍÏÓÔÕÖÚÇ-]', '', text_response)
        
        # Gera o áudio realista
        audio_base64 = await generate_voice_base64(clean_text)
        
        return {
            "text": clean_text,
            "audio": audio_base64
        }
    except Exception as e:
        return {"error": f"Erro no processamento: {e}"}

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=7860)
