"""Scenario Description:

The scene shows a violet Audi A2 and a creased box 25 meters ahead in the same lane as the ego vehicle. It's raining.

"""

#################################
# MAP AND MODEL                 #
#################################

Town = 'Town03'
param map = localPath(f'../../assets/maps/CARLA/{Town}.xodr')
param carla_map = Town
model scenic.simulators.carla.model

#################################
# CONSTANTS                     #
#################################

WEATHER_OPTIONS = ['MidRainyNoon', 'HardRainNoon', 'SoftRainNoon', 'MidRainSunset', 'HardRainSunset', 'SoftRainSunset']
param weather = Uniform(*WEATHER_OPTIONS)

EGO_MODEL = 'vehicle.audi.a2'

#################################
# SCENARIO SPECIFICATION        #
#################################

ego = new Car,
    with blueprint EGO_MODEL,
    with color Color.withBytes([238, 130, 238])

new CreasedBox following roadDirection from ego for 25,
    with regionContainedIn ego.laneSection