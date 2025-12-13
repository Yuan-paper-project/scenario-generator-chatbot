"""Scenario Description:

The scene shows a yellow Volkswagen T2 and a prop 20 meters ahead in the same lane as the ego vehicle. It's clear weather.

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

WEATHER_OPTIONS = ['ClearNoon', 'ClearSunset']
param weather = Uniform(*WEATHER_OPTIONS)

EGO_MODEL = 'vehicle.volkswagen.t2'

#################################
# SCENARIO SPECIFICATION        #
#################################

ego = new Car,
    with blueprint EGO_MODEL,
    with color Color.withBytes([255, 255, 0])

new Prop following roadDirection from ego for 20,
    with regionContainedIn ego.laneSection