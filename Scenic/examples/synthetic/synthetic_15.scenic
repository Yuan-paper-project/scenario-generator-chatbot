"""Scenario Description:

The scene shows a beige Chevrolet Impala and a debris 25 meters ahead in the same lane as the ego vehicle. It's raining heavily.

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

WEATHER_OPTIONS = ['HardRainNoon', 'HardRainSunset']
param weather = Uniform(*WEATHER_OPTIONS)

EGO_MODEL = 'vehicle.chevrolet.impala'

#################################
# SCENARIO SPECIFICATION        #
#################################

ego = new Car,
    with blueprint EGO_MODEL,
    with color Color.withBytes([245, 245, 220])

new Debris following roadDirection from ego for 25,
    with regionContainedIn ego.laneSection