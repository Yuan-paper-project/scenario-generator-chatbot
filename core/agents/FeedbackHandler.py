from core.agents.base import BaseAgent
from core.prompts import load_prompt
from typing import Dict, Any

class FeedbackHandler(BaseAgent):
    def __init__(self):
        prompt = load_prompt("feedback_handler")
        super().__init__(prompt, use_rag=False)
    
    def process(self, scenario: str, user_feedback: str) -> Dict[str, Any]:
        response = self.invoke(context={
            "scenario": scenario,
            "user_feedback": user_feedback
        })
        return {
            "original_scenario": scenario,
            "user_feedback": user_feedback,
            "new_scenario": response,
        }

