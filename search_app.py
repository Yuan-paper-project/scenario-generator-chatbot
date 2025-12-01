import gradio as gr
from core.search_workflow import SearchWorkflow
from core.config import get_settings
import torch
import sys

settings = get_settings()



class SearchChatbotApp:
    def __init__(self):
        self.workflow = None
        self.thread_counter = 0
        self.awaiting_confirmation = False
        self.workflow_completed = False
    
    def initialize_workflow(self):
        if self.workflow:
            try:
                self.workflow.close()
            except:
                pass
        
        try:
            self.thread_counter += 1
            self.workflow = SearchWorkflow(thread_id=f"search_thread_{self.thread_counter}")
            self.awaiting_confirmation = False
            self.workflow_completed = False
        except Exception as e:
            error_msg = str(e)
            raise RuntimeError(f"Error happened: {error_msg}")
    
    def respond(self, message, history):
        if not message or not message.strip():
            return "Please provide a valid query."
        
        print(f"📥 Received user message: {message}")
        
        try:
            if self.workflow_completed:
                print("🔄 Previous workflow completed - starting new workflow for new query")
                self.initialize_workflow()
            
            if not self.workflow:
                self.initialize_workflow()
            
            if not self.awaiting_confirmation:
                result = self.workflow.run(user_input=message)
                self.awaiting_confirmation = True
                
                return result.get("messages", [])[-1].content
            
            else:
                message_lower = message.strip().lower()
                
                if message_lower in ["yes", "ok", "y", "confirm"]:
                    result = self.workflow.run(user_feedback=message)
                    
                    if result.get("workflow_status") == "completed":
                        self.awaiting_confirmation = False
                        self.workflow_completed = True
                        return result.get("messages", [])[-1].content
                    else:
                        return result.get("messages", [])[-1].content
                else:
                    print("📝 User provided feedback - updating interpretation...")
                    result = self.workflow.run(user_feedback=message)
                    
                    if result.get("workflow_status") == "completed":
                        self.awaiting_confirmation = False
                        self.workflow_completed = True
                    elif result.get("workflow_status") == "awaiting_confirmation":
                        self.awaiting_confirmation = True
                    
                    return result.get("messages", [])[-1].content
                    
        except Exception as e:
            error_msg = f"An error occurred: {str(e)}"
            print(f"❌ Error: {error_msg}")
            import traceback
            traceback.print_exc()
            self.awaiting_confirmation = False
            return f"Error happened: {error_msg}"
    
    def close(self):
        print("🧹 Cleaning up resources...")
        
        if self.workflow is not None:
            try:
                if hasattr(self.workflow, 'close'):
                    self.workflow.close()
            except Exception as e:
                print(f"⚠️ Error closing workflow: {e}")
            self.workflow = None
        
        try:
            if torch.cuda.is_available():
                torch.cuda.empty_cache()
                print("✅ CUDA cache cleared")
        except ImportError:
            pass
        
        print("✅ Cleanup completed")


if __name__ == "__main__":
    
    app = SearchChatbotApp()
    
    try:
        demo = gr.ChatInterface(
            fn=app.respond,
            title="Scenic Scenario Search & Retrieval",
            description="Search and retrieve similar Scenic scenarios from the database. The system will first show you a logical scenario structure for confirmation, then search the database and adapt the retrieved code to match your description.",
            examples=[
                "Ego vehicle is following an adversary vehicle. Adversary suddenly stops and then resumes moving forward.",
                "Ego vehicle performs a lane change to bypass a slow adversary vehicle before returning to its original lane.",
                "Ego vehicle yields to another vehicle while executing a maneuver at a four-way intersection."
            ],
        )
        
        print("\n🚀 Launching Gradio interface...")
        demo.launch(
            server_name="0.0.0.0",  # Allow external access
            server_port=7860,       # Default Gradio port
            share=False             # Set to True to create a public link
        )
    except KeyboardInterrupt:
        print("\n⚠️ Interrupted by user")
    except Exception as e:
        print(f"❌ Error launching interface: {e}")
        import traceback
        traceback.print_exc()
    finally:
        app.close()

