#################################
# Description                   #
#################################
description = "The ego is performing a right turn at an intersection when the crossing car suddenly speeds up, entering the intersection and causing the ego to brake abruptly to avoid a collision."

#################################
# Header                        #
#################################
Town = 'Town05'
param map = localPath(f'../../assets/maps/CARLA/{Town}.xodr') 
param carla_map = Town
model scenic.simulators.carla.model
EGO_MODEL = "vehicle.lincoln.mkz_2017"

#################################
# Ego                           #
#################################
param OPT_EGO_SPEED = Range(1, 5)  # The speed at which the ego vehicle approaches the intersection.
param OPT_EGO_YIELD_DIST = Range(8, 12)  # Distance to adv at which ego must decide

behavior EgoBehavior():
    try:
        do FollowTrajectoryBehavior(trajectory=egoTrajectory, target_speed=globalParameters.OPT_EGO_SPEED)
    interrupt when (withinDistanceToAnyObjs(self, globalParameters.OPT_EGO_YIELD_DIST)):
        take SetThrottleAction(0)
        take SetBrakeAction(1)
    terminate

ego = new Car at egoSpawnPt,
    with regionContainedIn None,
    with blueprint EGO_MODEL,
    with behavior EgoBehavior()

#################################
# Adversarial                   #
#################################
param OPT_EGO_SPEED = Range(1, 5)  # The speed at which the ego vehicle approaches the intersection.
param OPT_ADV_SPEED = globalParameters.OPT_EGO_SPEED * Uniform(0.8,0.9)  # The speed at which the adversarial vehicle approaches the intersection.
param OPT_ADV_DISTANCE = Range(20, 30)  # The critical distance at which the adversarial begins to accelerate.
param OPT_ADV_ACC_SPEED = globalParameters.OPT_ADV_SPEED * Uniform(1.8, 1.9, 2.0)  # The speed at which the adversarial vehicle accelerates after entering the intersection.

behavior AdvBehavior():
    do FollowTrajectoryBehavior(globalParameters.OPT_ADV_SPEED, advTrajectory) until (distance from self to ego < globalParameters.OPT_ADV_DISTANCE)
    do FollowTrajectoryBehavior(globalParameters.OPT_ADV_ACC_SPEED, advTrajectory)
    do FollowLaneBehavior(target_speed=globalParameters.OPT_ADV_SPEED)

AdvAgent = new Car following roadDirection from IntSpawnPt for -globalParameters.OPT_GEO_Y_DISTANCE,
    with heading IntSpawnPt.heading,
    with regionContainedIn None,
    with behavior AdvBehavior()

#################################
# Spatial Relation              #
#################################
param OPT_GEO_Y_DISTANCE = Range(20, 30)

intersection = Uniform(*filter(lambda i: i.is4Way, network.intersections))

egoManeuver = Uniform(*filter(lambda m: m.type is ManeuverType.RIGHT_TURN, intersection.maneuvers))
egoInitLane = egoManeuver.startLane
egoTrajectory = [egoInitLane, egoManeuver.connectingLane, egoManeuver.endLane]
egoSpawnPt = new OrientedPoint in egoInitLane.centerline

advManeuvers = filter(lambda m: m, egoManeuver.conflictingManeuvers)
advManeuver = Uniform(*advManeuvers)
advTrajectory = [advManeuver.startLane, advManeuver.connectingLane, advManeuver.endLane]
advSpawnPt = advManeuver.connectingLane.centerline[0]  
IntSpawnPt = advManeuver.connectingLane.centerline.start 

#################################
# Requirements and Restrictions #
#################################
require 30 <= (distance from egoSpawnPt to intersection) <= 40