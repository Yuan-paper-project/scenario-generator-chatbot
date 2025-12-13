"""Scenario Description:

The scene shows a pink Chevrolet Impala and a trash 19 meters ahead in the same lane as the ego vehicle. It's raining.

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

WEATHER_OPTIONS = ['MidRainyNoon', 'HardRainNoon', 'SoftRainNoon', 'MidRainSunset', 'HardRainSunset', 'SoftRainSunset']
param weather = Uniform(*WEATHER_OPTIONS)

EGO_MODEL = 'vehicle.chevrolet.impala'

#################################
# SCENARIO SPECIFICATION        #
#################################

ego = new Car,
    with blueprint EGO_MODEL,
    with color Color.withBytes([255, 192, 203])

new Trash following roadDirection from ego for 19,
    with regionContainedIn ego.laneSection