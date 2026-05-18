import asyncio
import sys
import io

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace')

from google import genai
from google.genai import types

async def test():
    client = genai.Client(api_key='AIzaSyB1ofjImnTEeXF6YBlMZKl2TDpLWT7QaiA')
    
    models_to_try = [
        'gemini-2.5-flash-native-audio-latest',
        'gemini-3.1-flash-live-preview',
    ]
    
    for model in models_to_try:
        try:
            print(f"Trying: {model}...")
            config = types.LiveConnectConfig(response_modalities=["AUDIO"])
            async with client.aio.live.connect(model=model, config=config) as session:
                print(f"  OK Connected to {model}")
                await session.send_client_content(
                    turns=types.Content(role="user", parts=[types.Part.from_text(text="Say hello briefly")])
                )
                async for resp in session.receive():
                    if resp.server_content and resp.server_content.model_turn:
                        for part in resp.server_content.model_turn.parts:
                            if part.inline_data:
                                print(f"  Got {len(part.inline_data.data)} bytes audio back")
                    if resp.server_content and resp.server_content.turn_complete:
                        print(f"  Turn complete for {model}")
                        break
        except Exception as e:
            print(f"  FAILED {model}: {e}")

asyncio.run(test())
