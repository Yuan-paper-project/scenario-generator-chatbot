import re
import logging

class SettingsUpdateAgent:
    def __init__(self):
        pass

    def process(self, code: str, blueprint: str = None, carla_map: str = None, weather: str = None) -> str:
        if not code:
            return code

        if blueprint:
            code = re.sub(r'model\s+["\']vehicle\.[^"\']+["\']', f"model '{blueprint}'", code)
            code = re.sub(r'MODEL\s*=\s*["\']vehicle\.[^"\']+["\']', f"MODEL = '{blueprint}'", code)
            logging.info(f"Updated blueprint to: {blueprint}")

        if carla_map:
            def map_replacer(match):
                full_path = match.group(1)
                new_path = re.sub(r'[^/]+\.xodr$', f"{carla_map}.xodr", full_path)
                return f"param map = localPath('{new_path}')"

            code = re.sub(r'param\s+map\s*=\s*localPath\([\'"]([^\'"]+)[\'"]\)', map_replacer, code)
            
            code = re.sub(r'param\s+carla_map\s*=\s*[\'"][^\'"]+[\'"]', f"param carla_map = '{carla_map}'", code)
            
            logging.info(f"Updated map to: {carla_map}")

        if weather:
            pass             
        return code
