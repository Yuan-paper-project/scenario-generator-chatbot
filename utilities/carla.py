from scenic.simulators.carla.simulator import CarlaSimulator
import carla 
import scenic
import subprocess
import time
import socket
import os

SCENARIO_PATH = r"C:\Workspace\scenario-generation-chatbot\Scenic\examples\test\54.scenic"

MAP='Town05'
MAP_PATH= r"C:\Workspace\scenario-generation-chatbot\Scenic\assets\maps\CARLA\Town05.xodr"
CARLA_PATH = r"C:\Install\CARLA_0.9.15\WindowsNoEditor\CarlaUE4.exe"
CARLA_HOST = '127.0.0.1'
CARLA_PORT = 2000


def is_carla_running(host, port):
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
        return s.connect_ex((host, port)) == 0


def start_carla():
    if is_carla_running(CARLA_HOST, CARLA_PORT):
        print("CARLA is already running.")
        return None

    print("Launching CARLA server...")
    process = subprocess.Popen(
        [CARLA_PATH, "-windowed", "-ResX=800", "-ResY=600"], 
        cwd=os.path.dirname(CARLA_PATH)
    )
    
    print("Waiting for CARLA to initialize (5s)...")
    time.sleep(5) # Give Unreal Engine time to load
    return process


carla_process = start_carla()
try:
    scenario = scenic.scenarioFromFile(SCENARIO_PATH, mode2D=True)
    simulator = CarlaSimulator(carla_map=MAP, map_path=MAP_PATH, timeout=30)
    scene, _ = scenario.generate()
    
    simulation = simulator.simulate(scene, maxSteps=1000)
    
    if simulation:
        print("Simulation finished successfully.")
    else:
        print("Simulation failed (e.g., rejection criteria met).")

except Exception as e:
    print(f"An error occurred: {e}")

finally:
    if 'simulator' in locals():
        simulator.destroy()
    if carla_process:
        print("Closing CARLA...")
        carla_process.kill()

    try:
        # /F = Forcefully terminate
        # /IM = Image Name (accepts wildcards)
        # /T = Terminates child processes as well
        subprocess.run(["taskkill", "/F", "/IM", "CarlaUE4*", "/T"], 
                       stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        print("Successfully killed all CARLA processes (Launcher & Shipping).")
    except Exception as e:
        print(f"Failed to run taskkill: {e}")