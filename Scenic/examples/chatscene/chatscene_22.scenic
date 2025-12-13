#################################
# Description                   #
#################################
description = "The ego vehicle is making an unprotected left turn; the adversarial vehicle approaches the intersection at a normal speed but then suddenly attempts to make a last-second right turn."

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
param OPT_EGO_SPEED = Range(3, 5)
param OPT_EGO_BRAKE_DIST = Range(8, 10) # Distance to adv at which ego must decide

behavior WaitBehavior():
    while True:
        wait

behavior EgoBehavior():
    initialDir = egoSpawnPt.heading
    try:
        do FollowTrajectoryBehavior(trajectory=egoTrajectory, target_speed=globalParameters.OPT_EGO_SPEED)
    interrupt when (withinDistanceToObjsInLane(self, globalParameters.OPT_EGO_BRAKE_DIST)):
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
param OPT_ADV_SPEED= Range(3, 6)
param OPT_ADV_LATETURN_DIST = Range(1, 3) # Distance in m for the adv to start its late turn

behavior AdvBehavior():
    do FollowTrajectoryBehavior(trajectory=advStraightTrajectory, target_speed=globalParameters.OPT_ADV_SPEED) until (distance from self to advLastMinuteManeuver.connectingLane.centerline < globalParameters.OPT_ADV_LATETURN_DIST)
    do FollowTrajectoryBehavior(trajectory=advStraightTrajectory, target_speed=globalParameters.OPT_ADV_SPEED) until (distance from self to advLastMinuteManeuver.connectingLane.centerline > globalParameters.OPT_ADV_LATETURN_DIST)
    do FollowTrajectoryBehavior(trajectory=advLastMinuteTrajectory, target_speed=globalParameters.OPT_ADV_SPEED)
    do FollowLaneBehavior(target_speed=globalParameters.OPT_ADV_SPEED)

AdvAgent = new Car at advSpawnPt,
    with heading advSpawnPt.heading,
    with regionContainedIn None,
    with behavior AdvBehavior()

#################################
# Spatial Relation              #
#################################
param OPT_ADV_START_DIST = Range(30, 50)   # How far away the adv car starts

intersection = Uniform(*filter(lambda i: i.is4Way, network.intersections))
egoManeuver = Uniform(*filter(lambda m: m.type is ManeuverType.LEFT_TURN, intersection.maneuvers))
egoTrajectory = [egoManeuver.startLane, egoManeuver.connectingLane, egoManeuver.endLane]
egoTrajectoryLine = egoManeuver.startLane.centerline + egoManeuver.connectingLane.centerline + egoManeuver.endLane.centerline
egoInitLane = egoManeuver.startLane
egoSpawnPt = new OrientedPoint in egoInitLane.centerline

advLastMinuteManeuver = Uniform(*filter(lambda m: m.type is ManeuverType.RIGHT_TURN, intersection.maneuvers))
advStraightManeuver = Uniform(*filter(lambda m: m.type is ManeuverType.STRAIGHT, advLastMinuteManeuver.startLane.maneuvers))
advStraightTrajectory = [advStraightManeuver.startLane, advStraightManeuver.connectingLane, advStraightManeuver.endLane]
advLastMinuteTrajectory = [advLastMinuteManeuver.startLane, advLastMinuteManeuver.connectingLane, advLastMinuteManeuver.endLane]
advInitLane = advLastMinuteManeuver.startLane

advSpawnPt = new OrientedPoint following advInitLane.orientation from advInitLane.centerline.end for -globalParameters.OPT_ADV_START_DIST

#################################
# Requirements and Restrictions #
#################################
require 30 <= (distance from egoSpawnPt to intersection) <= 40