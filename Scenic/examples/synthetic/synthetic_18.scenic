"""Scenario Description:

The scene shows a grey Audi TT and a iron plate 12 meters ahead in the same lane as the ego vehicle. It's sunset.

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

WEATHER_OPTIONS = ['ClearSunset', 'CloudySunset', 'WetSunset', 'WetCloudySunset', 'MidRainSunset', 'HardRainSunset', 'SoftRainSunset']
param weather = Uniform(*WEATHER_OPTIONS)

EGO_MODEL = 'vehicle.audi.tt'

#################################
# SCENARIO SPECIFICATION        #
#################################

ego = new Car,
    with blueprint EGO_MODEL,
    with color Color.withBytes([128, 128, 128])

new IronPlate following roadDirection from ego for 12,
    with regionContainedIn ego.laneSection