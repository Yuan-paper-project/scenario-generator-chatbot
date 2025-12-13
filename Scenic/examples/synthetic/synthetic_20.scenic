"""Scenario Description:

The scene shows a purple Nissan Micra and a mailbox 19 meters ahead in the same lane as the ego vehicle. It's clear weather.

"""

#################################
# MAP AND MODEL                 #
#################################

Town = 'Town10HD'
param map = localPath(f'../../assets/maps/CARLA/{Town}.xodr')
param carla_map = Town
model scenic.simulators.carla.model

#################################
# CONSTANTS                     #
#################################

WEATHER_OPTIONS = ['ClearNoon', 'ClearSunset']
param weather = Uniform(*WEATHER_OPTIONS)

EGO_MODEL = 'vehicle.nissan.micra'

#################################
# SCENARIO SPECIFICATION        #
#################################

ego = new Car,
    with blueprint EGO_MODEL,
    with color Color.withBytes([128, 0, 128])

new Mailbox following roadDirection from ego for 19,
    with regionContainedIn ego.laneSection