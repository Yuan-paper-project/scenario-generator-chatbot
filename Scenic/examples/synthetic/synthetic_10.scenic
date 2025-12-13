"""Scenario Description:

The scene shows a azure Mini Cooper S and a case 15 meters ahead in the same lane as the ego vehicle. The road is wet.

"""

#################################
# MAP AND MODEL                 #
#################################

Town = 'Town04'
param map = localPath(f'../../assets/maps/CARLA/{Town}.xodr')
param carla_map = Town
model scenic.simulators.carla.model

#################################
# CONSTANTS                     #
#################################

WEATHER_OPTIONS = ['WetNoon', 'WetCloudyNoon', 'WetSunset', 'WetCloudySunset']
param weather = Uniform(*WEATHER_OPTIONS)

EGO_MODEL = 'vehicle.mini.cooper_s'

#################################
# SCENARIO SPECIFICATION        #
#################################

ego = new Car,
    with blueprint EGO_MODEL,
    with color Color.withBytes([240, 255, 255])

new Case following roadDirection from ego for 15,
    with regionContainedIn ego.laneSection