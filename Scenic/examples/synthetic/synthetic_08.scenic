"""Scenario Description:

The scene shows a pink Toyota Prius and a busstop 10 meters ahead in the same lane as the ego vehicle. It's daytime.

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

WEATHER_OPTIONS = ['ClearNoon', 'CloudyNoon', 'WetNoon', 'WetCloudyNoon', 'MidRainyNoon', 'HardRainNoon', 'SoftRainNoon']
param weather = Uniform(*WEATHER_OPTIONS)

EGO_MODEL = 'vehicle.toyota.prius'

#################################
# SCENARIO SPECIFICATION        #
#################################

ego = new Car,
    with blueprint EGO_MODEL,
    with color Color.withBytes([255, 192, 203])

new BusStop following roadDirection from ego for 10,
    with regionContainedIn ego.laneSection