import gradio as gr
import logging
import time
import torch
import sys
import traceback
import concurrent.futures
from core.search_workflow import SearchWorkflow
from core.config import get_settings
from utilities.QueueHandler import QueueHandler


log_queue = QueueHandler()
root_logger = logging.getLogger()
root_logger.addHandler(log_queue)
root_logger.setLevel(logging.INFO)

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
            logging.info(f"🔄 Initializing new workflow thread: {self.thread_counter}")
            self.workflow = SearchWorkflow(thread_id=f"search_thread_{self.thread_counter}")
            self.awaiting_confirmation = False
            self.workflow_completed = False
        except Exception as e:
            error_msg = str(e)
            logging.error(f"❌ Error initializing workflow: {error_msg}")
            raise RuntimeError(f"Error happened: {error_msg}")
    
    def respond_generator(self, message, history):
        history = history or []
        
        if not message or not message.strip():
            logging.warning("Received empty query.")
            yield "", history, log_queue.get_logs(), gr.update(visible=False, value="")
            return

        history.append((message, "⏳ **Processing...**"))
        logging.info(f"📥 Received user message: {message}")
        
        yield "", history, log_queue.get_logs(), gr.update(visible=True, value="Processing...")
        
        try:
            if self.workflow_completed:
                logging.info("Status: Previous workflow completed. Resetting...")
                self.initialize_workflow()
                yield "", history, log_queue.get_logs(), gr.update(visible=True) # Keep loading visible
            
            if not self.workflow:
                self.initialize_workflow()
                yield "", history, log_queue.get_logs(), gr.update(visible=True) # Keep loading visible
            
            result = None
            run_func = None
            kwargs = {}
            
            if not self.awaiting_confirmation:
                logging.info(f"🚀 Running initial search for: '{message}'")
                run_func = self.workflow.run
                kwargs = {"user_input": message}
                
            else:
                message_lower = message.strip().lower()
                
                if message_lower in ["yes", "ok", "y", "confirm"]:
                    logging.info("✅ User confirmed structure. Generating code...")
                    run_func = self.workflow.run
                    kwargs = {"user_feedback": message}
                else:
                    logging.info("📝 User provided feedback. Refining results...")
                    run_func = self.workflow.run
                    kwargs = {"user_feedback": message}

            yield "", history, log_queue.get_logs(), gr.update(visible=True)

            with concurrent.futures.ThreadPoolExecutor(max_workers=1) as executor:
                future = executor.submit(run_func, **kwargs)
                
                while not future.done():
                    yield "", history, log_queue.get_logs(), gr.update(visible=True)
                    time.sleep(0.1)
                
                result = future.result()

            if not self.awaiting_confirmation:
                self.awaiting_confirmation = True
            else:
                if result.get("workflow_status") == "completed":
                    self.awaiting_confirmation = False
                    self.workflow_completed = True
                elif result.get("workflow_status") == "awaiting_confirmation":
                    self.awaiting_confirmation = True

            # Extract Response
            response_content = ""
            if result:
                response_content = result.get("messages", [])[-1].content
                logging.info("✅ Response generated successfully")
            
            history[-1] = (message, response_content)
            
            yield "", history, log_queue.get_logs(), gr.update(visible=False, value="")
            
        except Exception as e:
            error_msg = f"An error occurred: {str(e)}"
            logging.error(f"❌ Critical Error: {error_msg}")
            traceback.print_exc()
            self.awaiting_confirmation = False
            
            history[-1] = (message, f"Error: {error_msg}")
            yield "", history, log_queue.get_logs(), gr.update(visible=False, value="")

    def close(self):
        logging.info("🧹 Shutting down application...")
        if self.workflow is not None:
            try:
                if hasattr(self.workflow, 'close'):
                    self.workflow.close()
            except Exception as e:
                logging.error(f"Error closing workflow: {e}")
            self.workflow = None
        
        try:
            if torch.cuda.is_available():
                torch.cuda.empty_cache()
                logging.info("CUDA cache cleared")
        except ImportError:
            pass
        logging.info("Cleanup done.")


def create_demo():
    app = SearchChatbotApp()
    
    with gr.Blocks(title="Scenic Scenario Search", theme=gr.themes.Soft()) as demo:
        gr.Markdown("## 🚗 Scenic Scenario Search & Retrieval")
        gr.Markdown("Search database, confirm structure, and adapt code.")
        
        with gr.Row():
            # -- Left Column: Chat --
            with gr.Column(scale=2):
                chatbot = gr.Chatbot(height=600, label="Conversation")
                msg = gr.Textbox(
                    label="Input", 
                    placeholder="Ego vehicle yields to another vehicle...",
                    lines=1 
                )
                with gr.Row():
                    submit_btn = gr.Button("Submit", variant="primary")

            with gr.Column(scale=1):
                with gr.Row():
                    gr.Markdown("### 🛠️ Live System Logs")
                    clear_btn = gr.Button("Clear", scale=0)
                
                log_output = gr.Textbox(
                    label="Backend Execution Logs",
                    lines=30, 
                    interactive=False
                )

        msg.submit(
            app.respond_generator, 
            inputs=[msg, chatbot], 
            outputs=[msg, chatbot, log_output ]
        )
        
        submit_btn.click(
            app.respond_generator, 
            inputs=[msg, chatbot], 
            outputs=[msg, chatbot, log_output]
        )
        
        def clear_ui():
            app.initialize_workflow() 
            log_queue.clear()         
            return [], "", "", gr.update(visible=False, value="") 
            
        clear_btn.click(clear_ui, outputs=[chatbot, log_output, msg])
        
        gr.Examples(
            examples=[
                "Ego vehicle is following an adversary vehicle. Adversary suddenly stops.",
                "Ego vehicle performs a lane change to bypass a slow adversary.",
                "Ego vehicle yields to another vehicle at a four-way intersection."
            ],
            inputs=msg
        )

    return demo, app

if __name__ == "__main__":
    demo, app = create_demo()
    
    try:
        print("\n🚀 Launching Gradio interface...")
        demo.queue() 
        demo.launch(
            server_name="0.0.0.0", 
            server_port=7860, 
            share=False
        )
    except KeyboardInterrupt:
        print("\n⚠️ Interrupted by user")
    except Exception as e:
        print(f"❌ Error launching interface: {e}")
        traceback.print_exc()
    finally:
        app.close()
