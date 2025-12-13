#################################
# Description                   #
#################################
description = "The ego vehicle is driving on a straight road following a leading vehicle; the adversarial pedestrian appears from a driveway on the left and suddenly stops and walks diagonally."

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
param OPT_EGO_BRAKE_DISTANCE = Range(7, 15)

behavior AvoidObjectsInLaneBehavior(speed,distance):
    try:
        do FollowLaneBehavior(target_speed=speed)
    interrupt when withinDistanceToObjsInLane(self, thresholdDistance=distance):
        take SetBrakeAction(1)

ego = new Car at egoSpawnPt,
    with regionContainedIn None,
    with blueprint EGO_MODEL,
    with behavior AvoidObjectsInLaneBehavior(globalParameters.OPT_EGO_SPEED,globalParameters.OPT_EGO_BRAKE_DISTANCE)

#################################
# Adversarial                   #
#################################
param OPT_LEADING_BRAKE_DISTANCE = Range(7, 15)
param OPT_LEADING_SPEED = Range(1, 5)

behavior AvoidObjectsInLaneBehavior(speed,distance):
    try:
        do FollowLaneBehavior(target_speed=speed)
    interrupt when withinDistanceToObjsInLane(self, thresholdDistance=distance):
        take SetBrakeAction(1)

LeadingAgent = new Car at LeadingSpawnPt,
    with behavior AvoidObjectsInLaneBehavior(globalParameters.OPT_LEADING_SPEED, globalParameters.OPT_LEADING_BRAKE_DISTANCE),

#################################
# Adversarial                   #
#################################
param OPT_ADV_SPEED = Range(1, 3)
param OPT_WAIT_SEC_1 = Range(1, 3)
param OPT_WAIT_SEC_2 = Range(1, 3)
param OPT_OTHER_DIRECTION = Uniform(+45, -45)
param OPT_GEO_X_DISTANCE = Range(2, 10)

behavior WaitBehavior():
    while True:
        wait

behavior WalkStopDiagonalBehavior(adv_speed, wait_sec_1, wait_sec_2, other_direction):
    initialDirection = self.heading
    secondaryDirection = self.heading + other_direction deg
    take SetWalkingDirectionAction(initialDirection)
    take SetWalkingSpeedAction(adv_speed)
    do WaitBehavior() for wait_sec_1 seconds
    take SetWalkingSpeedAction(0)
    do WaitBehavior() for wait_sec_2 seconds
    take SetWalkingDirectionAction(secondaryDirection)
    take SetWalkingSpeedAction(adv_speed)

AdvAgent = new Pedestrian left of IntSpawnPt by globalParameters.OPT_GEO_X_DISTANCE,
    with heading egoSpawnPt.heading - 90 deg,
    with regionContainedIn None,
    with behavior WalkStopDiagonalBehavior(
        globalParameters.OPT_ADV_SPEED,
        globalParameters.OPT_WAIT_SEC_1,
        globalParameters.OPT_WAIT_SEC_2,
        globalParameters.OPT_OTHER_DIRECTION
    )

#################################
# Spatial Relation              #
#################################
param OPT_LEADING_DISTANCE = Range(0, 30)
param OPT_GEO_Y_DISTANCE = Range(20, 35)

intersection = Uniform(*filter(lambda i: i.is4Way and not i.isSignalized, network.intersections))
egoInitLane = Uniform(*intersection.incomingLanes)
advLane = egoInitLane
egoManeuver = Uniform(*filter(lambda m: m.type is ManeuverType.STRAIGHT, egoInitLane.maneuvers))
egoTrajectoryLine = egoInitLane.centerline + egoManeuver.connectingLane.centerline + egoManeuver.endLane.centerline

egoSpawnPt = new OrientedPoint in egoManeuver.startLane.centerline
LeadingSpawnPt = new OrientedPoint following egoInitLane.orientation from egoSpawnPt for globalParameters.OPT_LEADING_DISTANCE
IntSpawnPt = new OrientedPoint following egoInitLane.orientation from egoSpawnPt for globalParameters.OPT_GEO_Y_DISTANCE

#################################
# Requirements and Restrictions #
#################################
require 40 <= (distance to intersection) <= 60
terminate when distance from ego to intersection > 60