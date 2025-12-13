"""Scenario Description:

The scene shows a orange Citroen C3 and a plant pot 24 meters ahead in the same lane as the ego vehicle. It's raining heavily.

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

WEATHER_OPTIONS = ['HardRainNoon', 'HardRainSunset']
param weather = Uniform(*WEATHER_OPTIONS)

EGO_MODEL = 'vehicle.citroen.c3'

#################################
# SCENARIO SPECIFICATION        #
#################################

ego = new Car,
    with blueprint EGO_MODEL,
    with color Color.withBytes([255, 165, 0])

new PlantPot following roadDirection from ego for 24,
    with regionContainedIn ego.laneSection