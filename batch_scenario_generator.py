"""
Batch Scenario Generator

This script reads a text file containing scenario descriptions (one per line)
and automatically generates Scenic code for each scenario using the SearchWorkflow.
"""

import sys
import logging
import argparse
from pathlib import Path
from typing import List, Dict, Any
from datetime import datetime
import json

from core.search_workflow import SearchWorkflow
from core.config import get_settings
from utilities.AgentLogger import initialize_agent_logger, reset_agent_logger

# Configure logging - will be set up in main()
# to avoid conflicts with AgentLogger

settings = get_settings()


class BatchScenarioGenerator:
    def __init__(self, input_file: str, output_dir: str = "batch_results", 
                 selected_blueprint: str = None, selected_map: str = None, 
                 selected_weather: str = None, resume: bool = False):
        """
        Initialize the batch scenario generator.
        
        Args:
            input_file: Path to text file with scenario descriptions (one per line)
            output_dir: Directory to save generated scenarios
            selected_blueprint: CARLA blueprint for ego vehicle
            selected_map: CARLA map name
            selected_weather: Weather preset
            resume: Whether to skip already generated scenarios
        """
        self.input_file = Path(input_file)
        self.output_dir = Path(output_dir)
        self.output_dir.mkdir(parents=True, exist_ok=True)
        
        self.selected_blueprint = selected_blueprint
        self.selected_map = selected_map
        self.selected_weather = selected_weather
        self.resume = resume
        
        self.scenarios = []
        self.results = []
        
        # Statistics
        self.total_scenarios = 0
        self.successful = 0
        self.failed = 0
        
    def load_scenarios(self) -> List[str]:
        if not self.input_file.exists():
            raise FileNotFoundError(f"Input file not found: {self.input_file}")
        
        with open(self.input_file, 'r', encoding='utf-8') as f:
            scenarios = [line.strip() for line in f if line.strip()]
        
        self.scenarios = scenarios
        self.total_scenarios = len(scenarios)
        logging.info(f"📋 Loaded {self.total_scenarios} scenarios from {self.input_file}")
        return scenarios
    
    def generate_scenario(self, scenario_description: str, scenario_index: int) -> Dict[str, Any]:
        logging.info(f"\n{'='*80}")
        logging.info(f"🚀 Processing Scenario {scenario_index + 1}/{self.total_scenarios}")
        logging.info(f"📝 Description: {scenario_description}")
        logging.info(f"{'='*80}\n")
        
        result = {
            "scenario_index": scenario_index + 1,
            "description": scenario_description,
            "status": "pending",
            "generated_code": None,
            "error": None,
            "generation_id": None,
            "timestamp": datetime.now().isoformat()
        }
        
        workflow = None
        agent_logger = None
        
        try:
            thread_id = f"batch_scenario_{scenario_index + 1:03d}"
            workflow = SearchWorkflow(thread_id=thread_id)
            
            try:
                reset_agent_logger()
                agent_logger = initialize_agent_logger(user_query=scenario_description)
                result["generation_id"] = agent_logger.generation_id
            except Exception as e:
                agent_logger = None
            
            interpretation_result = workflow.run(
                user_input=scenario_description,
                selected_blueprint=self.selected_blueprint,
                selected_map=self.selected_map,
                selected_weather=self.selected_weather
            )
            
            if interpretation_result.get("workflow_status") != "awaiting_confirmation":
                raise Exception("Failed to get logical interpretation")
            
            logical_interpretation = interpretation_result.get("logical_interpretation", "")
            
            generation_result = workflow.run(
                user_feedback="yes",
                selected_blueprint=self.selected_blueprint,
                selected_map=self.selected_map,
                selected_weather=self.selected_weather
            )
            
            generated_code = generation_result.get("selected_code", "")
            
            if generated_code:
                result["status"] = "success"
                result["generated_code"] = generated_code
                result["logical_interpretation"] = logical_interpretation
                result["workflow_status"] = generation_result.get("workflow_status", "unknown")
                
                # Save generated code to file IMMEDIATELY
                scenario_file = self.output_dir / f"scenario_{scenario_index + 1:03d}.scenic"
                with open(scenario_file, 'w', encoding='utf-8') as f:
                    f.write(generated_code)
                
                result["output_file"] = str(scenario_file)
                
                self.successful += 1
            else:
                result["status"] = "failed"
                result["error"] = f"No code generated. Workflow status: {generation_result.get('workflow_status')}"
                self.failed += 1
            
            # Write agent logger summary
            if agent_logger:
                try:
                    agent_logger.write_summary()
                except Exception as e:
                    pass
            
            # Output summary for this scenario
            log_dir = agent_logger.results_dir if agent_logger else "N/A"
            status_icon = "✅" if result["status"] == "success" else "❌"
            logging.info(f"{status_icon} Scenario {scenario_index + 1:03d}: Logs -> {log_dir} | Status: {result['status'].upper()}")

        except Exception as e:
            result["status"] = "failed"
            result["error"] = str(e)
            self.failed += 1
            logging.error(f"❌ Scenario {scenario_index + 1:03d} failed: {e}")
        
        finally:
            # Cleanup
            if workflow:
                try:
                    workflow.close()
                except Exception as e:
                    logging.warning(f"Error closing workflow: {e}")
        
        return result
    
    def run(self):
        """Run batch generation for all scenarios."""
        # Set up local logging
        log_file = self.output_dir / "batch_generation.log"
        file_handler = logging.FileHandler(log_file, mode='a', encoding='utf-8')
        file_handler.setFormatter(logging.Formatter('%(asctime)s - %(levelname)s - %(message)s'))
        logging.getLogger().addHandler(file_handler)
        
        try:
            start_time = datetime.now()
            logging.info(f"\n{'='*80}")
            logging.info(f"🚀 Starting Batch Scenario Generation")
            logging.info(f"📁 Input file: {self.input_file}")
            logging.info(f"📂 Output directory: {self.output_dir}")
            logging.info(f"🗺️  Map: {self.selected_map}")
            logging.info(f"🚗 Blueprint: {self.selected_blueprint}")
            logging.info(f"🌤️  Weather: {self.selected_weather}")
            logging.info(f"{'='*80}\n")
            
            # Load scenarios
            try:
                self.load_scenarios()
            except Exception as e:
                logging.error(f"❌ Failed to load scenarios: {e}")
                return
            
            # Process each scenario
            for i, scenario_desc in enumerate(self.scenarios):
                scenario_id = i + 1
                scenario_file = self.output_dir / f"scenario_{scenario_id:03d}.scenic"
                
                if self.resume and scenario_file.exists():
                    logging.info(f"⏩ Skipping Scenario {scenario_id}/{self.total_scenarios} (Already exists: {scenario_file.name})")
                    # Create a placeholder result for the summary
                    result = {
                        "scenario_index": scenario_id,
                        "description": scenario_desc,
                        "status": "skipped",
                        "output_file": str(scenario_file),
                        "timestamp": datetime.fromtimestamp(scenario_file.stat().st_mtime).isoformat()
                    }
                    self.successful += 1
                    self.results.append(result)
                    continue
                
                result = self.generate_scenario(scenario_desc, i)
                self.results.append(result)
            
            # Save summary
            end_time = datetime.now()
            duration = end_time - start_time
            
            summary = {
                "start_time": start_time.isoformat(),
                "end_time": end_time.isoformat(),
                "duration_seconds": duration.total_seconds(),
                "total_scenarios": self.total_scenarios,
                "successful": self.successful,
                "failed": self.failed,
                "input_file": str(self.input_file),
                "output_directory": str(self.output_dir),
                "settings": {
                    "map": self.selected_map,
                    "blueprint": self.selected_blueprint,
                    "weather": self.selected_weather
                },
                "results": self.results
            }
            
            summary_file = self.output_dir / "batch_summary.json"
            with open(summary_file, 'w', encoding='utf-8') as f:
                json.dump(summary, f, indent=2, ensure_ascii=False)
            
            logging.info(f"\n{'='*80}")
            logging.info(f"🎉 Batch Generation Complete!")
            logging.info(f"{'='*80}")
            logging.info(f"⏱️  Duration: {duration}")
            logging.info(f"📊 Total scenarios: {self.total_scenarios}")
            logging.info(f"✅ Successful: {self.successful}")
            logging.info(f"❌ Failed: {self.failed}")
            logging.info(f"📄 Summary saved to: {summary_file}")
            logging.info(f"{'='*80}\n")
            
            # Print failed scenarios if any
            if self.failed > 0:
                logging.warning("\n⚠️  Failed Scenarios:")
                for result in self.results:
                    if result["status"] == "failed":
                        logging.warning(f"  - Scenario {result['scenario_index']}: {result['description']}")
                        logging.warning(f"    Error: {result['error']}")
        finally:
            # Clean up local logging
            logging.getLogger().removeHandler(file_handler)
            file_handler.close()


def main():
    # Configure logging before any other operations
    logging.basicConfig(
        level=logging.INFO,
        format='%(asctime)s - %(levelname)s - %(message)s',
        handlers=[
            logging.StreamHandler(sys.stdout)
        ]
    )

    # Silence other loggers to keep output clean
    logging.getLogger("core").setLevel(logging.WARNING)
    logging.getLogger("utilities").setLevel(logging.WARNING)
    logging.getLogger("httpx").setLevel(logging.WARNING)
    logging.getLogger("openai").setLevel(logging.WARNING)
    logging.getLogger("langgraph").setLevel(logging.WARNING)
    
    parser = argparse.ArgumentParser(
        description="Batch generate Scenic scenarios from a text file",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # Process a single file
  python batch_scenario_generator.py scenarios.txt

  # Process all .txt files in a directory (e.g., Benchmark/)
  python batch_scenario_generator.py Benchmark/

  # With custom CARLA settings
  python batch_scenario_generator.py scenarios.txt -m Town03 -b vehicle.tesla.model3 -w CloudyNoon

Input file format:
  Each line should contain one scenario description.
  Empty lines are ignored.
  
  Example:
    Ego vehicle follows a lead vehicle that suddenly brakes
    Ego vehicle performs a lane change to overtake a slow vehicle
    Pedestrian crosses the road in front of ego vehicle
        """
    )
    
    parser.add_argument(
        'input_file',
        help='Path to text file or directory containing text files'
    )
    
    parser.add_argument(
        '--resume',
        action='store_true',
        help='Resume generation by skipping already generated .scenic files'
    )
    
    parser.add_argument(
        '-o', '--output',
        default='batch_results',
        help='Output directory for generated scenarios (default: batch_results)'
    )
    
    parser.add_argument(
        '-m', '--map',
        default=None,
        help='CARLA map name (default: auto-detect or Town05)'
    )
    
    parser.add_argument(
        '-b', '--blueprint',
        default=None,
        help='CARLA blueprint for ego vehicle (default: auto-detect or vehicle.lincoln.mkz_2017)'
    )
    
    parser.add_argument(
        '-w', '--weather',
        default=None,
        help='Weather preset (default: auto-detect or ClearNoon)'
    )
    
    args = parser.parse_args()
    
    input_path = Path(args.input_file)
    
    if input_path.is_dir():
        txt_files = sorted(list(input_path.glob("*.txt")))
        if not txt_files:
            logging.error(f"No .txt files found in {input_path}")
            return
            
        logging.info(f"📂 Found {len(txt_files)} text files in {input_path}")
        
        for txt_file in txt_files:
            # Output directory is input_path / file_stem (e.g., Benchmark/NHTSA_Crash/)
            output_dir = input_path / txt_file.stem
            
            logging.info(f"\n{'#'*80}")
            logging.info(f"📄 Processing file: {txt_file.name}")
            logging.info(f"📂 Output directory: {output_dir}")
            logging.info(f"{'#'*80}")
            
            generator = BatchScenarioGenerator(
                input_file=str(txt_file),
                output_dir=str(output_dir),
                selected_blueprint=args.blueprint,
                selected_map=args.map,
                selected_weather=args.weather,
                resume=args.resume
            )
            generator.run()
    else:
        # Original behavior for a single file
        generator = BatchScenarioGenerator(
            input_file=args.input_file,
            output_dir=args.output,
            selected_blueprint=args.blueprint,
            selected_map=args.map,
            selected_weather=args.weather,
            resume=args.resume
        )
        generator.run()


if __name__ == "__main__":
    main()

