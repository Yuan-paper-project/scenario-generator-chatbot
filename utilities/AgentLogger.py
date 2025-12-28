import os
import json
import logging
from datetime import datetime
from typing import Optional, Dict, Any
from pathlib import Path


class AgentLogger:
    def __init__(self, generation_id: Optional[str] = None):
        self.generation_id = generation_id or datetime.now().strftime("%Y%m%d_%H%M%S")
        self.results_dir = Path("results") / self.generation_id
        self.results_dir.mkdir(parents=True, exist_ok=True)
        
        self.invocation_counter = {}
        
        self.global_counter = 0
        
        self.session_log_file = self.results_dir / "session_log.jsonl"
        
        self._write_session_metadata()
        
        logging.info(f"📁 AgentLogger initialized. Logs will be saved to: {self.results_dir}")
    
    def _write_session_metadata(self):
        metadata = {
            "generation_id": self.generation_id,
            "start_time": datetime.now().isoformat(),
            "results_directory": str(self.results_dir)
        }
        
        metadata_file = self.results_dir / "generation_metadata.json"
        with open(metadata_file, 'w', encoding='utf-8') as f:
            json.dump(metadata, f, indent=2)
    
    def _format_agent_name(self, agent_name: str, metadata: Optional[Dict[str, Any]] = None) -> str:
        if agent_name == "ComponentScoringAgent" and metadata:
            component_type = metadata.get("component_type", "")
            if component_type:
                component_type = component_type.replace("_", "")
                return f"Scoring{component_type}Agent"
        return agent_name
    
    def log_agent_interaction(
        self,
        agent_name: str,
        system_prompt: Optional[str] = None,
        user_prompt: Optional[str] = None,
        full_prompt: Optional[str] = None,
        context: Optional[Dict[str, Any]] = None,
        response: Optional[str] = None,
        metadata: Optional[Dict[str, Any]] = None
    ):
        formatted_agent_name = self._format_agent_name(agent_name, metadata)
        self.global_counter += 1
        if formatted_agent_name not in self.invocation_counter:
            self.invocation_counter[formatted_agent_name] = 0
        self.invocation_counter[formatted_agent_name] += 1
        timestamp = datetime.now().isoformat()
        log_entry = {
            "agent_name": formatted_agent_name,
            "timestamp": timestamp,
            "full_prompt": full_prompt,
            "response": response
        }
        
        with open(self.session_log_file, 'a', encoding='utf-8') as f:
            f.write(json.dumps(log_entry, ensure_ascii=False) + '\n')
        
        agent_log_file = self.results_dir / f"{self.global_counter}.{formatted_agent_name}.txt"
        self._write_detailed_log(agent_log_file, log_entry)
        
        logging.debug(f"📝 Logged {formatted_agent_name} as #{self.global_counter}")
    
    def _write_detailed_log(self, file_path: Path, log_entry: Dict[str, Any]):
        with open(file_path, 'w', encoding='utf-8') as f:
            f.write("=" * 80 + "\n")
            f.write(f"AGENT: {log_entry['agent_name']}\n")
            f.write(f"TIMESTAMP: {log_entry['timestamp']}\n")
            f.write("=" * 80 + "\n\n")
            
            f.write("-" * 80 + "\n")
            f.write("PROMPT\n")
            f.write("-" * 80 + "\n")
            if log_entry.get('full_prompt'):
                f.write(log_entry['full_prompt'])
            else:
                f.write("(No prompt)")
            f.write("\n\n")
            
            f.write("-" * 80 + "\n")
            f.write("RESPONSE\n")
            f.write("-" * 80 + "\n")
            if log_entry.get('response'):
                f.write(log_entry['response'])
            else:
                f.write("(No response)")
            f.write("\n\n")
            
            f.write("=" * 80 + "\n")
            f.write("END OF LOG\n")
            f.write("=" * 80 + "\n")
    
    def log_workflow_event(self, event_type: str, event_data: Dict[str, Any]):
        timestamp = datetime.now().isoformat()
        
        log_entry = {
            "event_type": event_type,
            "timestamp": timestamp,
            "event_data": event_data
        }
        
        workflow_log_file = self.results_dir / "workflow_events.jsonl"
        with open(workflow_log_file, 'a', encoding='utf-8') as f:
            f.write(json.dumps(log_entry, ensure_ascii=False) + '\n')
    
    def get_summary(self) -> Dict[str, Any]:
        return {
            "generation_id": self.generation_id,
            "results_directory": str(self.results_dir),
            "agent_invocations": dict(self.invocation_counter),
            "total_invocations": sum(self.invocation_counter.values())
        }
    
    def write_summary(self):
        summary = self.get_summary()
        summary["end_time"] = datetime.now().isoformat()
        
        summary_file = self.results_dir / "generation_summary.json"
        with open(summary_file, 'w', encoding='utf-8') as f:
            json.dump(summary, f, indent=2)
        
        logging.info(f"📊 Generation summary written to: {summary_file}")


_global_agent_logger: Optional[AgentLogger] = None


def get_agent_logger() -> Optional[AgentLogger]:
    return _global_agent_logger


def initialize_agent_logger(session_id: Optional[str] = None) -> AgentLogger:
    global _global_agent_logger
    _global_agent_logger = AgentLogger(session_id)
    return _global_agent_logger


def reset_agent_logger():
    global _global_agent_logger
    if _global_agent_logger:
        _global_agent_logger.write_summary()
    _global_agent_logger = None

