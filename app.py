import gradio as gr
import logging
import time
import torch
import sys
import traceback
import concurrent.futures
from core.workflow import SearchWorkflow
from core.config import get_settings
from utilities.QueueHandler import QueueHandler
from utilities.carla_utils import get_carla_blueprints, get_carla_maps
from utilities.AgentLogger import initialize_agent_logger, reset_agent_logger, get_agent_logger
settings = get_settings()


log_queue = QueueHandler()
root_logger = logging.getLogger()
root_logger.addHandler(log_queue)
root_logger.setLevel(logging.INFO)

# Suppress HTTP logs
logging.getLogger("httpx").setLevel(logging.WARNING)
logging.getLogger("httpcore").setLevel(logging.WARNING)
logging.getLogger("pymilvus").setLevel(logging.WARNING)
logging.getLogger("sentence_transformers").setLevel(logging.WARNING)


class SearchChatbotApp:
    def __init__(self):
        self.workflow = None
        self.thread_counter = 0
        self.awaiting_confirmation = False
        self.workflow_completed = False
        self.agent_logger = None
        self.generation_counter = 0
    
    def initialize_workflow(self):
        if self.workflow:
            try:
                self.workflow.close()
            except:
                pass
        
        self.thread_counter += 1
        session_id = f"search_thread_{self.thread_counter}"
        
        try:
            self.workflow = SearchWorkflow(thread_id=session_id)
            self.awaiting_confirmation = False
            self.workflow_completed = False
            logging.info(f"🚀 Workflow initialized with thread ID: {session_id}")
        except Exception as e:
            error_msg = str(e)
            logging.error(f"❌ Error initializing workflow: {error_msg}")
            raise RuntimeError(f"Error happened: {error_msg}")
    
    def respond_generator(self, message, history, current_code):
        history = history or []
        
        if not message or not message.strip():
            yield "", history, log_queue.get_logs(), current_code
            return

        history.append({"role": "user", "content": message})
        history.append({"role": "assistant", "content": "⏳ **Processing...**"})
        
        yield "", history, log_queue.get_logs(), current_code
        
        try:
            if self.workflow_completed:
                self.initialize_workflow()
                yield "", history, log_queue.get_logs(), current_code
            
            if not self.workflow:
                self.initialize_workflow()
                yield "", history, log_queue.get_logs(), current_code
            
            if not self.awaiting_confirmation:
                reset_agent_logger()
                self.generation_counter += 1
                self.agent_logger = initialize_agent_logger(user_query=message)
                logging.info(f"📁 New generation started: {self.agent_logger.generation_id}")
            
            result = None
            run_func = None
            kwargs = {}
            
            if not self.awaiting_confirmation:
                logging.info(f"📝 Waiting for user confirmation")
                kwargs["user_input"] = message
                
            else:
                message_lower = message.strip().lower()
                
                if message_lower in ["yes", "ok", "y", "confirm"]:
                    logging.info("✅ User confirmed structure. ")
                    kwargs["user_feedback"] = message
                else:
                    logging.info("📝 Receieve user provided feedback")
                    kwargs["user_feedback"] = message

            yield "", history, log_queue.get_logs(), current_code

            with concurrent.futures.ThreadPoolExecutor(max_workers=1) as executor:
                future = executor.submit(self.workflow.run, **kwargs)
                
                while not future.done():
                    yield "", history, log_queue.get_logs(), current_code
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
            
            if result.get("workflow_status") == "completed" and self.agent_logger:
                self.agent_logger.write_summary()
                logging.info(f"📊 Agent logs saved to: {self.agent_logger.results_dir}")

            # Extract Response
            response_content = ""
            new_code = current_code
            
            if result:
                response_content = result.get("messages", [])[-1].content
                generated_code = result.get("adapted_code", "")
                if generated_code:
                    new_code = generated_code
            
            history[-1] = {"role": "assistant", "content": response_content}
            
            yield "", history, log_queue.get_logs(), new_code
            
        except Exception as e:
            error_msg = f"An error occurred: {str(e)}"
            logging.error(f"❌ Critical Error: {error_msg}")
            traceback.print_exc()
            self.awaiting_confirmation = False
            
            history[-1] = {"role": "assistant", "content": f"Error: {error_msg}"}
            yield "", history, log_queue.get_logs(), current_code

    def close(self):
        logging.info("🧹 Close the application")
        
        if self.agent_logger:
            try:
                self.agent_logger.write_summary()
                logging.info(f"📊 Final agent logs saved to: {self.agent_logger.results_dir}")
            except Exception as e:
                logging.error(f"Error writing agent logger summary: {e}")
        
        reset_agent_logger()
        
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
        except ImportError:
            pass
        logging.info("Cleanup done.")

def create_demo():
    app = SearchChatbotApp()
    
    blueprints = get_carla_blueprints()
    maps = get_carla_maps()
    print(f"Loaded {len(blueprints)} blueprints and {len(maps)} maps.")
    

    with gr.Blocks(title="Scenic Scenario Search", theme=gr.themes.Soft(), css=".center-row { align-items: center !important; }")as demo:
        gr.Markdown("## 🚗 Scenic Scenario Generation")
        gr.Markdown("Send your request, confirm the structure, and generate the code.")
        
        with gr.Row():
            with gr.Column(scale=7):
                chatbot = gr.Chatbot(height=600, label="Conversation", type='messages')
                
                with gr.Row(equal_height=False, elem_classes="center-row"):
                            msg = gr.Textbox(
                                show_label=False,
                                container=False,
                                placeholder="Ego vehicle yields to another vehicle...",
                                lines=(2, 5),
                                scale=8
                            )
                            submit_btn = gr.Button("Send", variant="primary", scale=1)
                        
                with gr.Column():
                    gr.Markdown("### Examples")
                    example_texts = [
                        "Ego vehicle is following an adversary vehicle. Adversary suddenly stops.",
                        "Ego vehicle performs a lane change to bypass a slow adversary.",
                        "Ego vehicle yields to another vehicle at a four-way intersection."
                    ]
                    for text in example_texts:
                        ex_btn = gr.Button(text, size="sm", variant="secondary")
                        ex_btn.click(fn=lambda t=text: t, inputs=[], outputs=msg)

            with gr.Column(scale=3):
                log_output = gr.Textbox(
                    label="Backend Execution Logs",
                    lines=10, 
                    interactive=False
                )
                
                code_display = gr.Code(
                    label="Generated Scenic Code (Editable)",
                    language="python",
                    interactive=True
                )

        input_components = [msg, chatbot, code_display]
        output_components = [msg, chatbot, log_output, code_display]

        msg.submit(
            app.respond_generator, 
            inputs=input_components, 
            outputs=output_components
        )
        
        submit_btn.click(
            app.respond_generator, 
            inputs=input_components, 
            outputs=output_components
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
