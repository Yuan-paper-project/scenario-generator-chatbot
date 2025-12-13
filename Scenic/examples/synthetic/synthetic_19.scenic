"""Scenario Description:

The scene shows a olive Nissan Patrol and a kiosk 15 meters ahead in the same lane as the ego vehicle. It's clear weather.

"""

#################################
# MAP AND MODEL                 #
#################################

Town = 'Town01'
param map = localPath(f'../../assets/maps/CARLA/{Town}.xodr')
param carla_map = Town
model scenic.simulators.carla.model

#################################
# CONSTANTS                     #
#################################

WEATHER_OPTIONS = ['ClearNoon', 'ClearSunset']
param weather = Uniform(*WEATHER_OPTIONS)

EGO_MODEL = 'vehicle.nissan.patrol'

#################################
# SCENARIO SPECIFICATION        #
#################################

ego = new Car,
    with blueprint EGO_MODEL,
    with color Color.withBytes([128, 128, 0])

new Kiosk following roadDirection from ego for 15,
    with regionContainedIn ego.laneSection