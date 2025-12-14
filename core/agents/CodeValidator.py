import socket
from Scenic.src.scenic.simulators.carla.simulator import CarlaSimulator
from core.agents.base import BaseAgent
from core.prompts import load_prompt
from typing import Dict, Any, Optional
import scenic
import tempfile
import os
import logging
import subprocess
import time
from core.config import get_settings

settings = get_settings()


class CodeValidator():
    
    def __init__(self):
        pass 

    def validate_scenic_code(self, code: str):
       
        scenic_file_path = self.write_code_to_file(code)
        carla_process = self.start_carla()
        try:
            scenario = scenic.scenarioFromFile(scenic_file_path, mode2D=True)
            simulator = CarlaSimulator(carla_map=settings.MAP, map_path=settings.MAP_PATH, timeout=30)
            scene, _ = scenario.generate()
            simulation = simulator.simulate(scene, maxSteps=1000)

            return True, None
        except Exception as e:
            return False, str(e)
        finally:
            if os.path.exists(scenic_file_path):
                os.remove(scenic_file_path)
            self.close_carla(carla_process, simulator if 'simulator' in locals() else None)

    def process(self, code: str) -> Dict[str, Any]:
        current_code = code
        is_valid, error = self.validate_scenic_code(current_code)
        if is_valid:
            logging.info("Validation Successful.")
            self.last_response = f"Validation Result: Valid\nCode:\n{current_code}"
            return {
                "valid": True,
                "error": None,
                "code": current_code
            }
        else:
            logging.error(f"Error: {error}")
            return {
                "valid": False,
                "error": error,
                "code": current_code
            }

    def write_code_to_file(self, code: str):
        target_dir = os.path.join(os.getcwd(), "Scenic", "examples", "test")
        os.makedirs(target_dir, exist_ok=True)

        with tempfile.NamedTemporaryFile(suffix=".scenic", mode='w+', delete=False, dir=target_dir) as temp_file:
            temp_file.write(code)
            temp_file_path = temp_file.name
        
        return temp_file_path
    

    def is_carla_running(self, host, port):
        with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
            return s.connect_ex((host, port)) == 0


    def start_carla(self):
        if self.is_carla_running('127.0.0.1', 2000):
            print("CARLA is already running.")
            return None

        print("Launching CARLA server...")
        process = subprocess.Popen(
            [settings.CARLA_PATH, "-windowed", "-ResX=800", "-ResY=600"], 
            cwd=os.path.dirname(settings.CARLA_PATH)
        )
        
        print("Waiting for CARLA to initialize (2s)...")
        time.sleep(2) 
        return process
    
    def close_carla(self, carla_process, simulator):
        if simulator:
            simulator.destroy()
        if carla_process:
            print("Closing CARLA...")
            carla_process.kill()

        try:
            # /F = Forcefully terminate
            # /IM = Image Name (accepts wildcards)
            # /T = Terminates child processes as well
            subprocess.run(["taskkill", "/F", "/IM", "CarlaUE4*", "/T"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            print("Successfully killed all CARLA processes (Launcher & Shipping).")
        except Exception as e:
            print(f"Failed to run taskkill: {e}")