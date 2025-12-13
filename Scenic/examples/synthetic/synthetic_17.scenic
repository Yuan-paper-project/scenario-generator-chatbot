"""Scenario Description:

The scene shows a pink Nissan Patrol and a gnome 17 meters ahead in the same lane as the ego vehicle. It's sunset.

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

WEATHER_OPTIONS = ['ClearSunset', 'CloudySunset', 'WetSunset', 'WetCloudySunset', 'MidRainSunset', 'HardRainSunset', 'SoftRainSunset']
param weather = Uniform(*WEATHER_OPTIONS)

EGO_MODEL = 'vehicle.nissan.patrol'

#################################
# SCENARIO SPECIFICATION        #
#################################

ego = new Car,
    with blueprint EGO_MODEL,
    with color Color.withBytes([255, 192, 203])

new Gnome following roadDirection from ego for 17,
    with regionContainedIn ego.laneSection