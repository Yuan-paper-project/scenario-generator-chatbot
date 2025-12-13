"""Scenario Description:

The scene shows a brown Lincoln MKZ and a garbage 19 meters ahead in the same lane as the ego vehicle. It's clear weather.

"""

#################################
# MAP AND MODEL                 #
#################################

Town = 'Town05'
param map = localPath(f'../../assets/maps/CARLA/{Town}.xodr')
param carla_map = Town
model scenic.simulators.carla.model

#################################
# CONSTANTS                     #
#################################

WEATHER_OPTIONS = ['ClearNoon', 'ClearSunset']
param weather = Uniform(*WEATHER_OPTIONS)

EGO_MODEL = 'vehicle.lincoln.mkz_2017'

#################################
# SCENARIO SPECIFICATION        #
#################################

ego = new Car,
    with blueprint EGO_MODEL,
    with color Color.withBytes([165, 42, 42])

new Garbage following roadDirection from ego for 19,
    with regionContainedIn ego.laneSection