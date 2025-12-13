"""Scenario Description:

The scene shows a olive Audi E-Tron and a truck 10 meters ahead in the same lane as the ego vehicle. It's daytime.

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

EGO_MODEL = 'vehicle.audi.etron'

#################################
# SCENARIO SPECIFICATION        #
#################################

ego = new Car,
    with blueprint EGO_MODEL,
    with color Color.withBytes([128, 128, 0])

new Truck following roadDirection from ego for 10,
    with regionContainedIn ego.laneSection