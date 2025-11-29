from .base import BaseAgent
from core.prompts import load_prompt

class CodeAdapterAgent(BaseAgent):
    def __init__(self):
        
        prompt = load_prompt("code_adapter")
        super().__init__(
            prompt_template=prompt,
            model_name="gemini-2.5-flash",
            model_provider="google_genai",
            use_rag=False
        )
    
    def process(self, user_description: str, retrieved_code: str) -> str:
        response = self.invoke(context={
            "user_description": user_description,
            "retrieved_code": retrieved_code
        })
        return self._extract_code_from_response(response.strip())

