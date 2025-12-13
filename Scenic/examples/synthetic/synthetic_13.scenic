"""Scenario Description:

The scene shows a grey Ford Mustang and a container 11 meters ahead in the same lane as the ego vehicle. It's raining.

"""

#################################
# MAP AND MODEL                 #
#################################

Town = 'Town07'
param map = localPath(f'../../assets/maps/CARLA/{Town}.xodr')
param carla_map = Town
model scenic.simulators.carla.model

#################################
# CONSTANTS                     #
#################################

WEATHER_OPTIONS = ['MidRainyNoon', 'HardRainNoon', 'SoftRainNoon', 'MidRainSunset', 'HardRainSunset', 'SoftRainSunset']
param weather = Uniform(*WEATHER_OPTIONS)

EGO_MODEL = 'vehicle.ford.mustang'

#################################
# SCENARIO SPECIFICATION        #
#################################

ego = new Car,
    with blueprint EGO_MODEL,
    with color Color.withBytes([128, 128, 128])

new Container following roadDirection from ego for 11,
    with regionContainedIn ego.laneSection