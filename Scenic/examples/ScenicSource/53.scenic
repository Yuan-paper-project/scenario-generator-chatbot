#################################
# Description                   #
#################################

description = "Ego vehicle must suddenly stop to avoid collision when pedestrian crosses the road unexpectedly from left to right."

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
param EGO_BRAKE = Range(0.8, 1.0)
SAFE_DIST = 20

behavior EgoBehavior():
    try:
        do FollowLaneBehavior(target_speed=globalParameters.EGO_SPEED)
    interrupt when withinDistanceToObjsInLane(self, SAFE_DIST) and (ped in network.drivableRegion):
        take SetBrakeAction(globalParameters.EGO_BRAKE)

#################################
# Adversarial Behavior          #
#################################

PED_MIN_SPEED = 1.0
PED_THRESHOLD = 20

behavior PedestrianBehavior():
    do CrossingBehavior(ego, PED_MIN_SPEED, PED_THRESHOLD)

#################################
# Spatial Relation              #
#################################

lane = Uniform(*network.lanes)
egoSpawnPt = new OrientedPoint on lane.centerline

#################################
# Ego object                    #
#################################

param EGO_INIT_DIST = Range(-30, -20)

ego = new Car following roadDirection from egoSpawnPt for globalParameters.EGO_INIT_DIST,
    with blueprint MODEL,
    with behavior EgoBehavior()

#################################
# Adversarial object            #
#################################

ped = new Pedestrian left of egoSpawnPt by 3,
    facing -90 deg relative to egoSpawnPt.heading,
    with regionContainedIn None,
    with behavior PedestrianBehavior()

#################################
# Requirements and Restrictions #
#################################

INIT_DIST = 75
TERM_DIST = 100

require (distance to intersection) > INIT_DIST
require always (ego.laneSection._slowerLane is None)
require always (ego.laneSection._fasterLane is None)
terminate when (distance to egoSpawnPt) > TERM_DIST