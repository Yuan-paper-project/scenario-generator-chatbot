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

        if carla_map:
            def map_replacer(match):
                full_path = match.group(1)
                new_path = re.sub(r'[^/]+\.xodr$', f"{carla_map}.xodr", full_path)
                return f"param map = localPath('{new_path}')"

            code = re.sub(r'param\s+map\s*=\s*localPath\([\'"]([^\'"]+)[\'"]\)', map_replacer, code)
            
            code = re.sub(r'param\s+carla_map\s*=\s*[\'"][^\'"]+[\'"]', f"param carla_map = '{carla_map}'", code)
            

        if weather:
            weather_param_line = f"param weather = '{weather}'"
            
            if re.search(r'param\s+weather\s*=\s*[\'"][^\'"]+[\'"]', code):
                code = re.sub(r'param\s+weather\s*=\s*[\'"][^\'"]+[\'"]', weather_param_line, code)
            else:
                last_param_match = re.search(r'(param\s+(map|carla_map)\s*=[\s\S]*?)(?=\n\S|\Z)', code)
                if last_param_match:
                    code = code[:last_param_match.end(1)] + f"\n{weather_param_line}" + code[last_param_match.end(1):]
                else:
                    first_line_after_imports = re.search(r'^(import\s+.*\n)*\n*', code)
                    insert_index = first_line_after_imports.end() if first_line_after_imports else 0
                    code = code[:insert_index] + f"{weather_param_line}\n" + code[insert_index:]
        return code
