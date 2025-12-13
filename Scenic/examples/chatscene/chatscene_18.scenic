#################################
# Description                   #
#################################
description = "The ego moves straight at an intersection when a crossing vehicle runs the red light from right and brakes abruptly, causing the ego to rapidly adapt its trajectory and perform a collision avoidance maneuver."

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
param OPT_BRAKE_DISTANCE = Range(5, 8)
param OPT_EGO_SPEED = Range (1, 5)

ego = new Car at egoSpawnPt,
    with regionContainedIn None,
    with blueprint EGO_MODEL,
    with behavior DriveAvoidingCollisions(target_speed=globalParameters.OPT_EGO_SPEED, avoidance_threshold=globalParameters.OPT_BRAKE_DISTANCE)

#################################
# Adversarial                   #
#################################
param OPT_ADV_SPEED = Range(1, 5)
param OPT_ADV_DISTANCE = Range(40, 70)
OPT_ADV_STOP_DISTANCE = 1

behavior WaitBehavior():
    while True:
        wait

behavior AdvBehavior(actor_reference, adv_speed, adv_distance, stop_reference, stop_distance):
    do WaitBehavior() until (distance from self to actor_reference) <= adv_distance
    do FollowLaneBehavior(adv_speed) until distance from self to stop_reference <= stop_distance
    take SetThrottleAction(0)
    take SetBrakeAction(1)

AdvAgent = new Car at advSpawnPt,
    with heading advSpawnPt.heading,
    with regionContainedIn None,
    with behavior AdvBehavior(ego, globalParameters.OPT_ADV_SPEED,globalParameters.OPT_ADV_DISTANCE, egoTrajectoryLine, OPT_ADV_STOP_DISTANCE)

#################################
# Spatial Relation              #
#################################
intersection = Uniform(*filter(lambda i: i.is4Way and i.isSignalized, network.intersections))

egoManeuver = Uniform(*filter(lambda m: m.type is ManeuverType.STRAIGHT, intersection.maneuvers))
egoInitLane = egoManeuver.startLane
egoTrajectory = [egoInitLane, egoManeuver.connectingLane, egoManeuver.endLane]
egoTrajectoryLine = egoInitLane.centerline + egoManeuver.connectingLane.centerline + egoManeuver.endLane.centerline
egoSpawnPt = new OrientedPoint in egoInitLane.centerline

advManeuver = Uniform(*filter(lambda m: m.type is ManeuverType.STRAIGHT, egoManeuver.conflictingManeuvers))
advInitLane = advManeuver.startLane
advTrajectory = [advInitLane, advManeuver.connectingLane, advManeuver.endLane]
advSpawnPt = new OrientedPoint in advInitLane.centerline

egoDir = egoSpawnPt.heading
advDir = advSpawnPt.heading

#################################
# Requirements and Restrictions #
#################################
CONST_RIGHT_DEG = - 90 deg
CONST_TOL_DEG = 20 deg
CONST_MIN_RIGHT_DEG = CONST_RIGHT_DEG - CONST_TOL_DEG
CONST_MAX_RIGHT_DEG = CONST_RIGHT_DEG + CONST_TOL_DEG

monitor TrafficLights():
    freezeTrafficLights()
    while True:
        if withinDistanceToTrafficLight(ego, 100):
            setClosestTrafficLightStatus(ego, "green")
        if withinDistanceToTrafficLight(AdvAgent, 100):
            setClosestTrafficLightStatus(AdvAgent, "red")
        wait

require CONST_MIN_RIGHT_DEG < (egoDir - advDir) < CONST_MAX_RIGHT_DEG
require monitor TrafficLights()
require 30 <= (distance from egoSpawnPt to intersection) <= 40
require 5 <= (distance from advSpawnPt to intersection) <= 10