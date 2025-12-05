#################################
# Description                   #
#################################

description = "Both ego and adversary vehicles must suddenly stop to avoid collision when pedestrian crosses the road unexpectedly from right to the left."

#################################
# Header                        #
#################################

param map = localPath('../../assets/maps/CARLA/Town05.xodr')
param carla_map = 'Town05'
model scenic.simulators.carla.model

MODEL = 'vehicle.mini.cooper_s_2021'

#################################
# Ego                           #
#################################

param EGO_SPEED = Range(7, 10)
EGO_BRAKE = 1.0

# Shared parameters, duplicated as per rules
param SAFETY_DIST = Range(10, 15)
CRASH_DIST = 5
TIME = 5

behavior EgoBehavior():
    try:
        do FollowLaneBehavior(target_speed=globalParameters.EGO_SPEED)
    interrupt when withinDistanceToObjsInLane(self, globalParameters.SAFETY_DIST) and (ped in network.drivableRegion):
        take SetBrakeAction(EGO_BRAKE)
    interrupt when withinDistanceToAnyObjs(self, CRASH_DIST):
        do FollowLaneBehavior(target_speed=globalParameters.EGO_SPEED) for TIME seconds

param EGO_INIT_DIST = Range(-30, -20)

ego = new Car following roadDirection from spawnPt for globalParameters.EGO_INIT_DIST,
    with blueprint MODEL,
    with behavior EgoBehavior()

#################################
# Adversarial                   #
#################################

PED_MIN_SPEED = 1.0
PED_THRESHOLD = 20

behavior PedestrianBehavior():
    do CrossingBehavior(ego, PED_MIN_SPEED, PED_THRESHOLD)

ped = new Pedestrian right of spawnPt by 3,
    facing 90 deg relative to spawnPt.heading,
    with regionContainedIn None,
    with behavior PedestrianBehavior()

#################################
# Adversarial                   #
#################################

param ADV_SPEED = Range(7, 10)
ADV_BRAKE = 1.0

# Shared parameters, duplicated as per rules
param SAFETY_DIST = Range(10, 15)
CRASH_DIST = 5
TIME = 5

param ADV_INIT_DIST = Range(40, 50)

behavior AdvBehavior():
    try:
        do FollowLaneBehavior(target_speed=globalParameters.ADV_SPEED)
    interrupt when (withinDistanceToObjsInLane(self, globalParameters.SAFETY_DIST) or (distance from adv to ped) < 10) and (ped in network.drivableRegion):
        take SetBrakeAction(ADV_BRAKE)
    interrupt when withinDistanceToAnyObjs(self, CRASH_DIST):
        do FollowLaneBehavior(target_speed=globalParameters.ADV_SPEED) for TIME seconds

adv = new Car left of advSpawnPt by 3,
    with blueprint MODEL,
    facing 180 deg relative to spawnPt.heading,
    with behavior AdvBehavior()

#################################
# Spatial Relation              #
#################################

road = Uniform(*filter(lambda r: len(r.forwardLanes.lanes) == len(r.backwardLanes.lanes) == 1, network.roads))
egoLane = Uniform(road.forwardLanes.lanes)[0]
spawnPt = new OrientedPoint on egoLane.centerline
advSpawnPt = new OrientedPoint following roadDirection from spawnPt for globalParameters.ADV_INIT_DIST

#################################
# Requirements and Restrictions #
#################################

BUFFER_DIST = 75
TERM_DIST = 50

require (distance from spawnPt to intersection) > BUFFER_DIST
require always (ego.laneSection._slowerLane is None)
require always (ego.laneSection._fasterLane is None)
require always (adv.laneSection._slowerLane is None)
require always (adv.laneSection._fasterLane is None)
terminate when (distance to spawnPt) > TERM_DIST