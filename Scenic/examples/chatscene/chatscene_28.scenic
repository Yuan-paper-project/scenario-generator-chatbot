#################################
# Description                   #
#################################
description = "The ego vehicle is turning right; the adversarial car (positioned ahead on the right) reverses abruptly."

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
param OPT_EGO_SPEED = Range(5, 8)
param OPT_BRAKE_DIST = Range(5, 10)

behavior EgoBehavior():
    try:
        do FollowTrajectoryBehavior(trajectory=egoTrajectory, target_speed=globalParameters.OPT_EGO_SPEED)
    interrupt when (withinDistanceToObjsInLane(self, globalParameters.OPT_BRAKE_DIST)):
        take SetThrottleAction(0)
        take SetBrakeAction(1)
    terminate

ego = new Car at egoSpawnPt,
    with regionContainedIn egoLaneSec,
    with blueprint EGO_MODEL,
    with behavior EgoBehavior()

#################################
# Adversarial                   #
#################################
param OPT_ADV_SPEED = Range(5, 8)
param OPT_ADV_REVERSE_SPEED = Range(1, 2)
param OPT_BRAKE_DIST = Range(5, 10)
param OPT_ADV_REVERSE_TIME = Range(1, 3)  # Time the adv waits before reversing

behavior WaitBehavior():
    while True:
        wait

behavior AdvBehavior():
    do FollowLaneBehavior(target_speed=globalParameters.OPT_ADV_SPEED) until (distance from self to egoManeuver.connectingLane < globalParameters.OPT_BRAKE_DIST)
    take SetThrottleAction(0)
    take SetBrakeAction(1)
    take SetReverseAction(True)
    take SetSpeedAction(globalParameters.OPT_ADV_REVERSE_SPEED)
    do WaitBehavior() for globalParameters.OPT_ADV_REVERSE_TIME seconds
    take SetReverseAction(False)
    take SetSpeedAction(globalParameters.OPT_ADV_SPEED)
    do FollowLaneBehavior(target_speed=globalParameters.OPT_ADV_SPEED)

AdvAgent = new Car at AdvSpawnPt,
    with regionContainedIn advLaneSec,
    with blueprint EGO_MODEL,
    with behavior AdvBehavior()

#################################
# Spatial Relation              #
#################################
param OPT_AHEAD_DIST = Range(5, 10)

intersection = Uniform(*filter(lambda i: i.is4Way, network.intersections))

egoManeuver = Uniform(*filter(lambda m: m.type is ManeuverType.RIGHT_TURN , intersection.maneuvers))
egoTrajectory = [egoManeuver.startLane, egoManeuver.connectingLane, egoManeuver.endLane]
egoTrajectoryLine = egoManeuver.startLane.centerline + egoManeuver.connectingLane.centerline + egoManeuver.endLane.centerline
egoLaneSec = egoManeuver.startLane
egoSpawnPt = new OrientedPoint in egoLaneSec.centerline

advLaneSec = egoLaneSec
AdvSpawnPt = new OrientedPoint following roadDirection from egoSpawnPt for globalParameters.OPT_AHEAD_DIST

#################################
# Requirements and Restrictions #
#################################
require 30 <= (distance from egoSpawnPt to intersection) <= 40