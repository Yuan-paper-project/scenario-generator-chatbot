#################################
# Description                   #
#################################
description = "Scenario Description: The ego vehicle is driving on a straight road; the adversarial pedestrian stands behind a bus stop on the right front, then suddenly sprints out onto the road in front of the ego vehicle and stops."

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
param OPT_EGO_SPEED = Range(1, 5)
param OPT_BRAKE_DIST = Range(6, 10)

behavior WaitBehavior():
    while True:
        wait

behavior EgoBehavior():
    try:
        do FollowLaneBehavior(globalParameters.OPT_EGO_SPEED)
    interrupt when (withinDistanceToObjsInLane(self, globalParameters.OPT_BRAKE_DIST)):
        take SetThrottleAction(0)
        take SetBrakeAction(1)
        do WaitBehavior() for 5 seconds
        terminate

ego = new Car at egoSpawnPt,
    with regionContainedIn None,
    with blueprint EGO_MODEL,
    with behavior EgoBehavior()

#################################
# Adversarial                   #
#################################
param OPT_GEO_BLOCKER_X_DISTANCE = Range(3, 5)


Blocker = new BusStop right of RightFrontSpawnPt by globalParameters.OPT_GEO_BLOCKER_X_DISTANCE,
    with heading RightFrontSpawnPt.heading,
    with regionContainedIn None

#################################
# Adversarial                   #
#################################
param OPT_ADV_SPEED = Range(1, 5)
param OPT_ADV_DISTANCE = Range(15, 20)

OPT_STOP_DISTANCE = 1

behavior CrossAndStopBehavior(actor_reference, adv_speed, adv_distance, stop_reference, stop_distance):
    do CrossingBehavior(actor_reference, adv_speed, adv_distance) until (distance from self to stop_reference <= stop_distance)
    take SetWalkingSpeedAction(0)


AdvAgent = new Pedestrian at Blocker offset along RightFrontSpawnPt.heading by SHIFT,
    with heading RightFrontSpawnPt.heading + 90 deg,  # Adjusted for sprinting out from the left
    with regionContainedIn None,
    with behavior CrossAndStopBehavior(ego, globalParameters.OPT_ADV_SPEED, globalParameters.OPT_ADV_DISTANCE, egoInitLane.centerline, OPT_STOP_DISTANCE)

#################################
# Spatial Relation              #
#################################
param OPT_GEO_X_DISTANCE = Range(-2, 2)
param OPT_GEO_Y_DISTANCE = Range(2, 6)
param OPT_GEO_BLOCKER_Y_DISTANCE = Range(20, 35)


intersection = Uniform(*filter(lambda i: i.is4Way and not i.isSignalized, network.intersections))
egoInitLane = Uniform(*intersection.incomingLanes)
egoManeuver = Uniform(*filter(lambda m: m.type is ManeuverType.STRAIGHT, egoInitLane.maneuvers))
egoTrajectoryLine = egoInitLane.centerline + egoManeuver.connectingLane.centerline + egoManeuver.endLane.centerline

egoSpawnPt = new OrientedPoint in egoManeuver.startLane.centerline
RightFrontSpawnPt = new OrientedPoint following egoInitLane.orientation from egoSpawnPt for globalParameters.OPT_GEO_BLOCKER_Y_DISTANCE

SHIFT = globalParameters.OPT_GEO_X_DISTANCE @ globalParameters.OPT_GEO_Y_DISTANCE
#################################
# Requirements and Restrictions #
#################################


require 40 <= (distance to intersection) <= 60