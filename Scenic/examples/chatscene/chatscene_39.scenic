#################################
# Description                   #
#################################
description = "The ego vehicle is turning right at an intersection; the adversarial pedestrian on the left of the target lane suddenly crosses the road and stops in the middle of the road, blocking the ego vehicle's path."

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
param OPT_BRAKE_DIST = Range(6, 10)
param OPT_EGO_SPEED = Range(1, 5)

behavior WaitBehavior():
    while True:
        wait

behavior EgoBehavior():
    try:
        do FollowTrajectoryBehavior(globalParameters.OPT_EGO_SPEED, egoTrajectory)
    interrupt when (withinDistanceToObjsInLane(self, globalParameters.OPT_BRAKE_DIST)):
        take SetThrottleAction(0)
        take SetBrakeAction(1)
        do WaitBehavior() for 5 seconds
        abort
    terminate

ego = new Car at egoSpawnPt,
    with regionContainedIn None,
    with blueprint EGO_MODEL,
    with behavior EgoBehavior()

#################################
# Adversarial                   #
#################################
param OPT_ADV_SPEED = Range(1, 5)
param OPT_ADV_DISTANCE = Range(25, 35)
OPT_STOP_DISTANCE = 1

behavior CrossAndStopBehavior(actor_reference, adv_speed, adv_distance, stop_reference, stop_distance):
    do CrossingBehavior(actor_reference, adv_speed, adv_distance) until (distance from self to stop_reference <= stop_distance)
    take SetWalkingSpeedAction(0)

AdvAgent = new Pedestrian at pedestrianSpawnPt,
    with heading pedestrianSpawnPt.heading,
    with regionContainedIn None,
    with behavior CrossAndStopBehavior(ego,globalParameters.OPT_ADV_SPEED,globalParameters.OPT_ADV_DISTANCE,egoManeuver.endLane.centerline, OPT_STOP_DISTANCE)

#################################
# Spatial Relation              #
#################################
param OPT_PARAM_OFFSET = 15

intersection = Uniform(*filter(lambda i: i.is4Way or i.is3Way, network.intersections))
egoManeuver = Uniform(*filter(lambda m: m.type is ManeuverType.RIGHT_TURN, intersection.maneuvers))
egoInitLane = egoManeuver.startLane
egoTrajectory = [egoInitLane, egoManeuver.connectingLane, egoManeuver.endLane]
egoTrajectoryLine = egoInitLane.centerline + egoManeuver.connectingLane.centerline + egoManeuver.endLane.centerline

egoSpawnPt = new OrientedPoint in egoInitLane.centerline
endLanePt = new OrientedPoint at egoManeuver.endLane.centerline.start,
    with heading egoInitLane.centerline.end.heading - 180 deg
pedestrianSpawnPt = new OrientedPoint ahead of endLanePt by - globalParameters.OPT_PARAM_OFFSET

#################################
# Requirements and Restrictions #
#################################
require 40 <= (distance to intersection) <= 60