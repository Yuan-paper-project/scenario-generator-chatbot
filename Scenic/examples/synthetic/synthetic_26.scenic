"""Scenario Description:

The scene shows a silver Nissan Micra and a traffic warning 13 meters ahead in the same lane as the ego vehicle. It's daytime.

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

WEATHER_OPTIONS = ['ClearNoon', 'CloudyNoon', 'WetNoon', 'WetCloudyNoon', 'MidRainyNoon', 'HardRainNoon', 'SoftRainNoon']
param weather = Uniform(*WEATHER_OPTIONS)

EGO_MODEL = 'vehicle.nissan.micra'

#################################
# SCENARIO SPECIFICATION        #
#################################

ego = new Car,
    with blueprint EGO_MODEL,
    with color Color.withBytes([192, 192, 192])

new TrafficWarning following roadDirection from ego for 13,
    with regionContainedIn ego.laneSection