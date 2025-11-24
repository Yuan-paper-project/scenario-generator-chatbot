#################################
# Description                   #
#################################

description = "Both ego and adversary vehicles must suddenly stop to avoid collision when pedestrian crosses the road diagonally unexpectedly from right to left."

#################################
# Header                        #
#################################

param map = localPath('../../assets/maps/CARLA/Town05.xodr')
param carla_map = 'Town05'
model scenic.simulators.carla.model

MODEL = 'vehicle.mini.cooper_s_2021'

#################################
# Ego Behavior                  #
#################################

param EGO_SPEED = Range(7, 10)
param EGO_BRAKE = Range(0.8,1.0)

behavior EgoBehavior():
    try:
        do FollowLaneBehavior(target_speed=globalParameters.EGO_SPEED)
    interrupt when withinDistanceToObjsInLane(self, SAFE_DIST) and (ped in network.drivableRegion):
        take SetBrakeAction(globalParameters.EGO_BRAKE)

#################################
# Adversarial Behavior          #
#################################

param ADV_SPEED = Range(7, 10)
param ADV_BRAKE = Range(0.8,1.0)

PED_MIN_SPEED = 1.0
PED_THRESHOLD = 20

behavior AdvBehavior():
    try:
        do FollowLaneBehavior(target_speed=globalParameters.ADV_SPEED)
    interrupt when (withinDistanceToObjsInLane(self, SAFE_DIST) or (distance from adv to ped) < 10) and (ped in network.drivableRegion):
        take SetBrakeAction(globalParameters.ADV_BRAKE)

behavior PedestrianBehavior():
    do CrossingBehavior(ego, PED_MIN_SPEED, PED_THRESHOLD)

#################################
# Spatial Relation              #
#################################

param EGO_INIT_DIST = Range(-30, -20)
param ADV_INIT_DIST = Range(40, 50)

INIT_DIST = 75
TERM_DIST = 100

road = Uniform(*filter(lambda r: len(r.forwardLanes.lanes) == len(r.backwardLanes.lanes) == 1, network.roads))
egoLane = Uniform(road.forwardLanes.lanes)[0]
egoSpawnPt = new OrientedPoint on egoLane.centerline
advSpawnPt = new OrientedPoint following roadDirection from egoSpawnPt for globalParameters.ADV_INIT_DIST

#################################
# Ego object                    #
#################################

SAFE_DIST = 20

ego = new Car following roadDirection from egoSpawnPt for globalParameters.EGO_INIT_DIST,
    with blueprint MODEL,
    with behavior EgoBehavior()

#################################
# Adversarial Object            #
#################################

ped = new Pedestrian right of egoSpawnPt by 3,
    facing 45 deg relative to egoSpawnPt.heading,
    with regionContainedIn None,
    with behavior PedestrianBehavior()

adv = new Car left of advSpawnPt by 3,
    with blueprint MODEL,
    facing 180 deg relative to egoSpawnPt.heading,
    with behavior AdvBehavior()

#################################
# Requirements and Restrictions #
#################################

require (distance from egoSpawnPt to intersection) > INIT_DIST
require always (ego.laneSection._slowerLane is None)
require always (ego.laneSection._fasterLane is None)
require always (adv.laneSection._slowerLane is None)
require always (adv.laneSection._fasterLane is None)
terminate when (distance to egoSpawnPt) > TERM_DIST