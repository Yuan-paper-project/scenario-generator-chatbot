"""Scenario Description:

The scene shows a violet Chevrolet Impala and a vending machine 18 meters ahead in the same lane as the ego vehicle. It's raining heavily.

"""

#################################
# MAP AND MODEL                 #
#################################

Town = 'Town03'
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
    with color Color.withBytes([238, 130, 238])

new VendingMachine following roadDirection from ego for 18,
    with regionContainedIn ego.laneSection