import json
from typing import Dict, Any
from .base import BaseAgent
from core.prompts import load_prompt


class ComponentScoringAgent(BaseAgent):

    
    def __init__(self):
        prompt = load_prompt("component_scoring")
        
        super().__init__(
            prompt_template=prompt,
            model_name="gemini-2.5-flash",
            model_provider="google_genai",
            use_rag=False
        )
    
    def process(self, component_type: str, user_criteria: str, retrieved_description: str) -> Dict[str, Any]:
        return self.score_component(component_type, user_criteria, retrieved_description)
    
    def score_component(
        self,
        component_type: str,
        user_criteria: str,
        retrieved_description: str
    ) -> Dict[str, Any]:
        response = self.invoke(context={
            "component_type": component_type,
            "user_criteria": user_criteria,
            "retrieved_description": retrieved_description
        })
        
        try:
            response_text = response.strip()
            
            if response_text.startswith("```json"):
                response_text = response_text[7:]
            elif response_text.startswith("```"):
                response_text = response_text[3:]
                
            if response_text.endswith("```"):
                response_text = response_text[:-3]
            
            response_text = response_text.strip()
            
            result = json.loads(response_text)
            
            required_fields = ["score", "is_satisfied", "differences"]
            for field in required_fields:
                if field not in result:
                    raise ValueError(f"Missing required field: {field}")
            
            result["score"] = max(0, min(100, result["score"]))
            result["user_criteria"] = user_criteria
            result["retrieved_description"] = retrieved_description
            
            return result
            
        except json.JSONDecodeError as e:
            print(f"[WARNING] Failed to parse scoring response as JSON: {e}")
            
            return {
                "score": 0,
                "is_satisfied": False,
                "differences": "Failed to parse scoring response",
                "user_criteria": user_criteria,
                "retrieved_description": retrieved_description
            }
        except Exception as e:
            print(f"[ERROR] Unexpected error in score_component: {e}")
            return {
                "score": 0,
                "is_satisfied": False,
                "differences": f"Error during scoring: {str(e)}",
                "user_criteria": user_criteria,
                "retrieved_description": retrieved_description
            }
    
    def score_multiple_components(
        self,
        component_scores: Dict[str, Dict[str, str]]
    ) -> Dict[str, Dict[str, Any]]:
        results = {}
        for component_type, criteria_desc in component_scores.items():
            user_criteria = criteria_desc.get("user_criteria", "")
            retrieved_description = criteria_desc.get("retrieved_description", "")
            
            if not user_criteria or not retrieved_description:
                print(f"[WARNING] Skipping {component_type}: missing criteria or description")
                continue
            
            print(f"[INFO] Scoring component: {component_type}")
            result = self.score_component(
                component_type=component_type,
                user_criteria=user_criteria,
                retrieved_description=retrieved_description
            )
            
            results[component_type] = result
            
            satisfied_str = "✓ satisfied" if result['is_satisfied'] else "✗ not satisfied"
            print(f"[INFO] {component_type} score: {result['score']}/100 ({satisfied_str})")
        
        return results

