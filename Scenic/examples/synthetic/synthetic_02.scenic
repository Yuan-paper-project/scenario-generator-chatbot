"""Scenario Description:

The scene shows a azure Nissan Micra and a advertisement 15 meters ahead in the same lane as the ego vehicle. The road is wet.

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

WEATHER_OPTIONS = ['WetNoon', 'WetCloudyNoon', 'WetSunset', 'WetCloudySunset']
param weather = Uniform(*WEATHER_OPTIONS)

EGO_MODEL = 'vehicle.nissan.micra'

#################################
# SCENARIO SPECIFICATION        #
#################################

ego = new Car,
    with blueprint EGO_MODEL,
    with color Color.withBytes([240, 255, 255])

new Advertisement following roadDirection from ego for 15,
    with regionContainedIn ego.laneSection