"""Scenario Description:

The scene shows a azure Audi E-Tron and a bicycle 24 meters ahead in the same lane as the ego vehicle. It's sunset.

"""

#################################
# MAP AND MODEL                 #
#################################

Town = 'Town02'
param map = localPath(f'../../assets/maps/CARLA/{Town}.xodr')
param carla_map = Town
model scenic.simulators.carla.model

#################################
# CONSTANTS                     #
#################################

WEATHER_OPTIONS = ['ClearSunset', 'CloudySunset', 'WetSunset', 'WetCloudySunset', 'MidRainSunset', 'HardRainSunset', 'SoftRainSunset']
param weather = Uniform(*WEATHER_OPTIONS)

EGO_MODEL = 'vehicle.audi.etron'

#################################
# SCENARIO SPECIFICATION        #
#################################

ego = new Car,
    with blueprint EGO_MODEL,
    with color Color.withBytes([240, 255, 255])

new Bicycle following roadDirection from ego for 24,
    with regionContainedIn ego.laneSection