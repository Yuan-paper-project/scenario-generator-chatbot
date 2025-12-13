#################################
# Description                   #
#################################
description = "The ego vehicle is driving on a straight road when a pedestrian suddenly crosses from the right front and suddenly stops as the ego vehicle approaches."

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
param OPT_ADV_SPEED = Range(1, 5)
param OPT_ADV_DISTANCE = Range(15, 20)
param OPT_GEO_X_DISTANCE = Range(3, 5)
param OPT_GEO_Y_DISTANCE = Range(20, 35)
OPT_STOP_DISTANCE = 1

behavior CrossAndStopBehavior(actor_reference, adv_speed, adv_distance, stop_reference, stop_distance):
    do CrossingBehavior(actor_reference, adv_speed, adv_distance) until (distance from self to stop_reference <= stop_distance)
    take SetWalkingSpeedAction(0)

AdvAgent = new Pedestrian right of IntSpawnPt by globalParameters.OPT_GEO_X_DISTANCE,
    with heading IntSpawnPt.heading + 90 deg,  # Heading perpendicular to the road, adjusted for left crossing
    with regionContainedIn None,
    with behavior CrossAndStopBehavior(ego, globalParameters.OPT_ADV_SPEED, globalParameters.OPT_ADV_DISTANCE, egoTrajectoryLine, OPT_STOP_DISTANCE)

#################################
# Spatial Relation              #
#################################
intersection = Uniform(*filter(lambda i: i.is4Way and not i.isSignalized, network.intersections))
egoInitLane = Uniform(*intersection.incomingLanes)
egoManeuver = Uniform(*filter(lambda m: m.type is ManeuverType.STRAIGHT, egoInitLane.maneuvers))
egoTrajectoryLine = egoInitLane.centerline + egoManeuver.connectingLane.centerline + egoManeuver.endLane.centerline

egoSpawnPt = new OrientedPoint in egoManeuver.startLane.centerline
IntSpawnPt = new OrientedPoint following egoInitLane.orientation from egoSpawnPt for globalParameters.OPT_GEO_Y_DISTANCE

#################################
# Requirements and Restrictions #
#################################
param OPT_BRAKE_DIST = Range(6, 10)

require 40 <= (distance to intersection) <= 60