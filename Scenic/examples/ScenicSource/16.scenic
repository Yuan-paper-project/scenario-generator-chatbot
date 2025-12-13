#################################
# Description                   #
#################################
description = "Ego vehicle must suddenly stop to avoid collision when pedestrian crosses the road unexpectedly from right to left side of the road."

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
param SAFETY_DIST = Range(10, 15)
CRASH_DIST = 5

behavior EgoBehavior():
    try:
        do FollowLaneBehavior(target_speed=globalParameters.EGO_SPEED)
    interrupt when withinDistanceToObjsInLane(self, globalParameters.SAFETY_DIST) and (ped in network.drivableRegion):
        take SetBrakeAction(EGO_BRAKE)
    interrupt when withinDistanceToAnyObjs(self, CRASH_DIST):
        terminate

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
# Spatial Relation              #
#################################
lane = Uniform(*network.lanes)
spawnPt = new OrientedPoint on lane.centerline

#################################
# Requirements and Restrictions #
#################################
BUFFER_DIST = 75
TERM_DIST = 50

require (distance to intersection) > BUFFER_DIST
require always (ego.laneSection._slowerLane is None)
require always (ego.laneSection._fasterLane is None)
terminate when (distance to spawnPt) > TERM_DIST