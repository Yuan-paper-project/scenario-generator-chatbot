"""Scenario Description:

The scene shows a burgundy Mini Cooper S and a cone 16 meters ahead in the same lane as the ego vehicle. It's cloudy.

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

WEATHER_OPTIONS = ['CloudyNoon', 'WetCloudyNoon', 'CloudySunset', 'WetCloudySunset']
param weather = Uniform(*WEATHER_OPTIONS)

EGO_MODEL = 'vehicle.mini.cooper_s'

#################################
# SCENARIO SPECIFICATION        #
#################################

ego = new Car,
    with blueprint EGO_MODEL,
    with color Color.withBytes([128, 0, 32])

new Cone following roadDirection from ego for 16,
    with regionContainedIn ego.laneSection