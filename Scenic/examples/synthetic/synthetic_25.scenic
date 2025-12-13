"""Scenario Description:

The scene shows a yellow Volkswagen T2 and a table 12 meters ahead in the same lane as the ego vehicle. It's raining heavily.

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

WEATHER_OPTIONS = ['HardRainNoon', 'HardRainSunset']
param weather = Uniform(*WEATHER_OPTIONS)

EGO_MODEL = 'vehicle.volkswagen.t2'

#################################
# SCENARIO SPECIFICATION        #
#################################

ego = new Car,
    with blueprint EGO_MODEL,
    with color Color.withBytes([255, 255, 0])

new Table following roadDirection from ego for 12,
    with regionContainedIn ego.laneSection