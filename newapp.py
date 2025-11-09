
import gradio as gr
from core.workflow import AgentWorkflow
import torch


class ChatbotApp:
    def __init__(self):
        self.workflow = None
        self.default_thread_id = "default_chat_session"
        self.current_status = None

    def respond(self, message, history):
        if not message or not message.strip():
            return "Please provide a valid query."
        
        print(f"📥 Received user message: {message}")
        
        try:
            # Initialize workflow if not already created
            if self.workflow is None:
                print(f"🆕 Creating new workflow with thread_id: {self.default_thread_id}")
                self.workflow = AgentWorkflow(
                    thread_id=self.default_thread_id,
                    max_retries=3
                )
            
            workflow = self.workflow
            
            if self.current_status in ["waiting_logical_confirmation", "waiting_detailed_confirmation"]:
                result = workflow.run(user_feedback=message)
            else:
                result = workflow.run(user_input=message)
            
            workflow_status = result.get("workflow_status", "")
            self.current_status = workflow_status
            
            if workflow_status == "waiting_logical_confirmation":
                scenario = result.get("scenario", "")
                message_text = result.get("message", "")
                
                response = (
                    f"{message_text}\n\n"
                    f"**Logical Scenario Structure:**\n"
                    f"```\n{scenario}\n```\n\n"
                    f"**Next steps:**\n"
                    f"\n- To proceed, reply with 'yes' or 'ok'. \n- If you need changes, reply with specific feedback.\n"
                )
                return response
                
            elif workflow_status == "waiting_detailed_confirmation":
                scenario = result.get("scenario", "")
                message_text = result.get("message", "")
                
                response = (
                    f"{message_text}\n\n"
                    f"**Detailed Scenario:**\n"
                    f"```\n{scenario}\n```\n\n"
                    f"**Next steps:**\n"
                    f"\n- To proceed, reply with 'yes' or 'ok'. \n- If you need changes, reply with specific feedback.\n"
                )
                return response
                
            elif workflow_status == "completed":
                code = result.get("code", "")
                is_valid = result.get("valid", False)
                message_text = result.get("message", "")
                
                if code:
                    if is_valid:
                        response = f"{message_text}\n\n**Generated Scenic Code:**\n\n```scenic\n{code}\n```"
                    else:
                        response = f"{message_text} (with validation errors)\n\n**Generated Scenic Code:**\n\n```scenic\n{code}\n```"
                else:
                    response = message_text
                
                # Reset status for next scenario
                self.current_status = None
                return response
                
            elif workflow_status == "error":
                error_msg = result.get("message", "An unknown error occurred")
                self.current_status = None
                return f"❌ Error: {error_msg}"
            else:
                self.current_status = None
                return f"⚠️ Unexpected workflow status: {workflow_status}"
            
        except Exception as e:
            error_msg = f"An error occurred: {str(e)}"
            print(f"❌ Error: {error_msg}")
            import traceback
            traceback.print_exc()
            self.current_status = None
            return error_msg

    def close(self):
        print("🧹 Cleaning up resources...")
        
        # Clear workflow
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
    app = ChatbotApp()
    try:
        # Create Gradio ChatInterface
        demo = gr.ChatInterface(
            fn=app.respond,
            title="Scenic DSL Code Generator",
            description="Generate Scenic DSL code from natural language descriptions of driving scenarios. The system will first show you a logical scenario structure, then a detailed scenario with specific parameters, before generating the final code.",
            examples=[
                "A car is driving on a straight road when a pedestrian suddenly crosses from the right.",
                "The ego vehicle approaches an intersection and a cyclist appears from the left side.",
                "A car is on a highway when a truck changes lanes in front of it."
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
