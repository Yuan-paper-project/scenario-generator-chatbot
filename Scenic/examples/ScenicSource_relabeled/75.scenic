#################################
# Description                   #
#################################
description = "Ego vehicle encounters a cyclings of a bicycle emerging crossing the road. Ego must perform an emergency brake."

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
SAFE_DIST = 15

behavior EgoBehavior(trajectory):
    try:
        do FollowTrajectoryBehavior(target_speed=globalParameters.EGO_SPEED, trajectory = trajectory)
    interrupt when withinDistanceToObjsInLane(self, SAFE_DIST):
        take SetBrakeAction(EGO_BRAKE)

ego = new Car at SpawnPt,
    with blueprint MODEL,
    with behavior EgoBehavior(egoTrajectory)

#################################
# Adversarial                   #
#################################
param BICYCLE_MIN_SPEED = 1.5
param BICYCLE_THRESHOLD = 18

behavior BicycleBehavior():
    do CrossingBehavior(ego, globalParameters.BICYCLE_MIN_SPEED, globalParameters.BICYCLE_THRESHOLD)

bicycle = new Bicycle at BicycleSpawnPt offset by 3.5@0,
    facing 90 deg relative to BicycleSpawnPt.heading,
    with behavior BicycleBehavior(),
    with regionContainedIn None

#################################
# Spatial Relation              #
#################################
intersection = Uniform(*network.intersections)
startLane = Uniform(*intersection.incomingLanes)
maneuver = Uniform(*startLane.maneuvers)
egoTrajectory = [maneuver.startLane, maneuver.connectingLane, maneuver.endLane]

SpawnPt = new OrientedPoint in maneuver.startLane.centerline

BicycleSpawnPt = new OrientedPoint in maneuver.endLane.centerline,
    facing roadDirection

#################################
# Requirements and Restrictions #
#################################
TERM_DIST = 50

require 10 <= (distance to intersection) <= 15
require 10 <= (distance from bicycle to intersection) <= 15
terminate when (distance to SpawnPt) > TERM_DIST