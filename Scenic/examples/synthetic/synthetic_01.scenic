"""Scenario Description:

The scene shows a brown Audi E-Tron and a ATM 18 meters ahead in the same lane as the ego vehicle. It's clear weather.

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

WEATHER_OPTIONS = ['ClearNoon', 'ClearSunset']
param weather = Uniform(*WEATHER_OPTIONS)

EGO_MODEL = 'vehicle.audi.etron'

#################################
# SCENARIO SPECIFICATION        #
#################################

ego = new Car,
    with blueprint EGO_MODEL,
    with color Color.withBytes([165, 42, 42])

new ATM following roadDirection from ego for 18,
    with regionContainedIn ego.laneSection