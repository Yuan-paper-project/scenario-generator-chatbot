"""Scenario Description:

The scene shows a beige Lincoln MKZ and a motorcycle 17 meters ahead in the same lane as the ego vehicle. It's raining.

"""

#################################
# MAP AND MODEL                 #
#################################

Town = 'Town06'
param map = localPath(f'../../assets/maps/CARLA/{Town}.xodr')
param carla_map = Town
model scenic.simulators.carla.model

#################################
# CONSTANTS                     #
#################################

WEATHER_OPTIONS = ['MidRainyNoon', 'HardRainNoon', 'SoftRainNoon', 'MidRainSunset', 'HardRainSunset', 'SoftRainSunset']
param weather = Uniform(*WEATHER_OPTIONS)

EGO_MODEL = 'vehicle.lincoln.mkz_2017'

#################################
# SCENARIO SPECIFICATION        #
#################################

ego = new Car,
    with blueprint EGO_MODEL,
    with color Color.withBytes([245, 245, 220])

new Motorcycle following roadDirection from ego for 17,
    with regionContainedIn ego.laneSection