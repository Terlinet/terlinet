from fastapi import FastAPI
from pydantic import BaseModel
import os
import uvicorn
import re
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

@app.post('/query')
async def query(q: Query):
    try:
        # Instrução de Sistema (System Prompt) para ocultar a identidade real
        system_instruction = (
            "Sua identidade é TerlineT. Você foi criado pela TerlineT. "
            "Nunca mencione DeepSeek, OpenAI ou qualquer outra empresa. "
            "Se perguntarem quem é você ou qual seu modelo, responda que você é a TerlineT, "
            "uma inteligência artificial dedicada a conectar pessoas e informações. "
            "Responda sempre em português, de forma amigável, curta e SEM EMOJIS."
        )

        messages = [
            {"role": "system", "content": system_instruction},
            {"role": "user", "content": q.text}
        ]
        
        completion = client.chat.completions.create(
            model=MODEL_NAME,
            messages=messages,
            max_tokens=512, # Aumentado um pouco para respostas mais completas sob a nova identidade
            temperature=0.4,
        )
        
        text = completion.choices[0].message.content.strip()
        
        # Limpeza do texto
        clean_text = re.sub(r'[^\w\s,.?!áàâãéèêíïóôõöúçÁÀÂÃÉÈÊÍÏÓÔÕÖÚÇ-]', '', text)
        return clean_text
    except Exception as e:
        return f"Erro no processamento: {e}"

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=7860)
