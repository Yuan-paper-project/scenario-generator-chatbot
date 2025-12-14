import json
from typing import Dict, Any, List
from .base import BaseAgent
from core.prompts import load_prompt
from core.milvus_client import MilvusClient
from core.scenario_milvus_client import ScenarioMilvusClient


class ComponentGeneratorAgent(BaseAgent):
    def __init__(self):
        prompt = load_prompt("component_generator")
        super().__init__(
            prompt_template=prompt,
            model_name="gemini-2.5-flash", 
            model_provider="google_genai",
            use_rag=False  
        )
        
        self.scenario_client = None
        self.doc_client = None
        
        try:
            self.scenario_client = ScenarioMilvusClient(collection_name="scenario_components_with_subject")
            print("[INFO] ComponentGeneratorAgent: Initialized ScenarioMilvusClient")
        except Exception as e:
            print(f"[WARNING] ComponentGeneratorAgent: Failed to initialize ScenarioMilvusClient: {e}")
        
        try:
            self.doc_client = MilvusClient(collection_name="documentation", embedding_provider="google_genai", embedding_model_name="models/gemini-embedding-001")
            print("[INFO] ComponentGeneratorAgent: Initialized documentation MilvusClient")
        except Exception as e:
            print(f"[WARNING] ComponentGeneratorAgent: Failed to initialize documentation client: {e}")
    
    def process(
        self,
        component_type: str,
        user_criteria: str,
        assembled_code: str = ""
    ) -> Dict[str, Any]:
        return self.generate_component(component_type, user_criteria, assembled_code)
    
    def generate_component(
        self,
        component_type: str,
        user_criteria: str,
        assembled_code: str = ""
    ) -> Dict[str, Any]:

        print(f"[INFO] Generating new {component_type} component...")
        
        reference_components = self._get_reference_components(user_criteria, component_type)
        
        documentation = self._get_documentation(component_type)
        
        response = self.invoke(context={
            "component_type": component_type,
            "user_criteria": user_criteria,
            "assembled_code": assembled_code if assembled_code else "# No previous code available",
            "reference_components": reference_components,
            "documentation": documentation
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
            
            # Validate required fields
            required_fields = ["code", "description"]
            for field in required_fields:
                if field not in result:
                    raise ValueError(f"Missing required field: {field}")
            
            print(f"[INFO] Successfully generated {component_type} component")
            print(f"[INFO] Description: {result.get('description', '')[:100]}...")
            
            return {
                "code": result["code"],
                "description": result["description"],
                "is_generated": True,  # Flag to indicate this was generated, not retrieved
                "scenario_id": "GENERATED"  # Special marker for generated components
            }
            
        except json.JSONDecodeError as e:
            print(f"[ERROR] Failed to parse generation response as JSON: {e}")
            print(f"[DEBUG] Response text: {response_text[:500]}...")
            
            return {
                "code": "",
                "description": "Failed to generate component",
                "is_generated": False,
                "scenario_id": "ERROR"
            }
        except Exception as e:
            print(f"[ERROR] Unexpected error in generate_component: {e}")
            return {
                "code": "",
                "description": "Failed to generate component",
                "is_generated": False,
                "scenario_id": "ERROR"
            }
    
    def _get_reference_components(self, query: str, component_type: str, limit: int = 3) -> str:

        if not self.scenario_client:
            return "# No reference components available"
        
        try:
            results = self.scenario_client.search_components_by_type(
                query=query,
                component_type=component_type,
                limit=limit
            )
            
            if not results:
                return "# No reference components found"
            
            formatted_refs = []
            for idx, hit in enumerate(results, 1):
                entity = hit.entity
                code = entity.get("code", "")
                description = entity.get("description", "")
                
                ref_json = {
                    "Description": description,
                    "Code": code,
                }
                formatted_refs.append(f"{json.dumps(ref_json, indent=2)}\n")
            
            return "\n".join(formatted_refs)
            
        except Exception as e:
            print(f"[ERROR] Failed to retrieve reference components: {e}")
            return "# Error retrieving reference components"
    
    def _get_documentation(self, component_type: str, top_k: int = 5) -> str:
        if not self.doc_client:
            return "# No documentation available"
        try:
            component_search_terms = {
                "Ego": "Ego,behavior",
                "Adversarial": "Adversarial,behavior",
                "Spatial Relation": "network,egoSpawnPt,intersection,egoTrajectory,advSpawnPt,advTrajectory",
                "Requirement and restrictions": "require,terminate,TrafficLight"
            }
            
            search_terms = component_search_terms.get(component_type, component_type)
            
            print(f"[INFO] Documentation search query: {search_terms}")
            
            results = self.doc_client.search(search_terms, ranker_type="rrf", ranker_params={"k": 5})
            if not results:
                return "# No relevant documentation found"
            
            doc_contents = []
            for idx, doc in enumerate(results[:top_k], 1):
                content = doc.page_content
                doc_contents.append(f"{content}\n")
            return "\n".join(doc_contents)
            
        except Exception as e:
            print(f"[ERROR] Failed to retrieve documentation: {e}")
            return "# Error retrieving documentation"
    
    def close(self):
        try:
            if self.scenario_client:
                self.scenario_client.close()
            if self.doc_client:
                self.doc_client.close()
            print("[INFO] ComponentGeneratorAgent resources cleaned up")
        except Exception as e:
            print(f"[WARNING] Error closing ComponentGeneratorAgent resources: {e}")
