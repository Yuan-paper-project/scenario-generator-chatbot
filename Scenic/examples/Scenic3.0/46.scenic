#################################
# DESCRIPTION                   #
#################################

description = "Ego vehicle must suddenly stop to avoid collision when pedestrian crosses the road diagonally unexpectedly from right to left side of the road."

#################################
# MAP AND MODEL                 #
#################################

param map = localPath('../../assets/maps/CARLA/Town05.xodr')
param carla_map = 'Town05'
model scenic.simulators.carla.model

#################################
# CONSTANTS                     #
#################################

MODEL = 'vehicle.mini.cooper_s_2021'

param EGO_INIT_DIST = Range(-30, -20)
param EGO_SPEED = Range(7, 10)
param EGO_BRAKE = Range(0.8, 1.0)

PED_MIN_SPEED = 1.0
PED_THRESHOLD = 20

SAFE_DIST = 20
INIT_DIST = 75
TERM_DIST = 100

#################################
# AGENT BEHAVIORS               #
#################################

behavior EgoBehavior():
    try:
        do FollowLaneBehavior(target_speed=globalParameters.EGO_SPEED)
    interrupt when withinDistanceToObjsInLane(self, SAFE_DIST) and (ped in network.drivableRegion):
        take SetBrakeAction(globalParameters.EGO_BRAKE)

behavior PedestrianBehavior():
    do CrossingBehavior(ego, PED_MIN_SPEED, PED_THRESHOLD)

#################################
# SPATIAL RELATIONS             #
#################################

lane = Uniform(*network.lanes)
egoSpawnPt = new OrientedPoint on lane.centerline

#################################
# SCENARIO SPECIFICATION        #
#################################

ego = new Car following roadDirection from egoSpawnPt for globalParameters.EGO_INIT_DIST,
    with blueprint MODEL,
    with behavior EgoBehavior()

ped = new Pedestrian left of egoSpawnPt by 3,
    facing -45 deg relative to egoSpawnPt.heading,
    with regionContainedIn None,
    with behavior PedestrianBehavior()

require (distance to intersection) > INIT_DIST
require always (ego.laneSection._slowerLane is None)
require always (ego.laneSection._fasterLane is None)
terminate when (distance to egoSpawnPt) > TERM_DIST
