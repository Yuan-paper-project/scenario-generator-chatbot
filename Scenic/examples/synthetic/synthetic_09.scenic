"""Scenario Description:

The scene shows a violet Citroen C3 and a car 25 meters ahead in the same lane as the ego vehicle. The road is wet.

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

WEATHER_OPTIONS = ['WetNoon', 'WetCloudyNoon', 'WetSunset', 'WetCloudySunset']
param weather = Uniform(*WEATHER_OPTIONS)

EGO_MODEL = 'vehicle.citroen.c3'

#################################
# SCENARIO SPECIFICATION        #
#################################

ego = new Car,
    with blueprint EGO_MODEL,
    with color Color.withBytes([238, 130, 238])

new Car following roadDirection from ego for 25,
    with regionContainedIn ego.laneSection