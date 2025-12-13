"""Scenario Description:

The scene shows a cream Nissan Patrol and a barrel 24 meters ahead in the same lane as the ego vehicle. The road is wet.

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

WEATHER_OPTIONS = ['WetNoon', 'WetCloudyNoon', 'WetSunset', 'WetCloudySunset']
param weather = Uniform(*WEATHER_OPTIONS)

EGO_MODEL = 'vehicle.nissan.patrol'

#################################
# SCENARIO SPECIFICATION        #
#################################

ego = new Car,
    with blueprint EGO_MODEL,
    with color Color.withBytes([255, 253, 208])

new Barrel following roadDirection from ego for 24,
    with regionContainedIn ego.laneSection