#################################
# Description                   #
#################################
description = "The ego is driving straight through an intersection when a crossing vehicle runs the red light and unexpectedly accelerates, forcing the ego to quickly reassess the situation and perform a collision avoidance maneuver."

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
param OPT_EGO_SPEED = Range (1, 6)
param OPT_BRAKE_DISTANCE = Range(5, 8)

behavior EgoBehavior():
    try:
        do FollowLaneBehavior(target_speed=globalParameters.OPT_EGO_SPEED)
    interrupt when (distance from self to AdvAgent < globalParameters.OPT_BRAKE_DISTANCE):
        take SetThrottleAction(0)  # Ensure no acceleration during braking
        take SetBrakeAction(1)  # Brake to avoid collision

ego = new Car at egoSpawnPt,
    with regionContainedIn None,
    with blueprint EGO_MODEL,
    with behavior EgoBehavior()

#################################
# Adversarial                   #
#################################
param OPT_ADV_SPEED = Range(1, 5)
param OPT_ADV_DISTANCE = Range(30, 50)
param OPT_ADV_ACC_DIST = Range(13,20)
param OPT_ADV_THROTTLE = Range(5, 10) / 10

behavior WaitBehavior():
    while True:
        wait

behavior AdvBehavior():
    do WaitBehavior() until (distance from self to ego) < globalParameters.OPT_ADV_DISTANCE
    do FollowLaneBehavior(target_speed=globalParameters.OPT_ADV_SPEED) until (distance from self to ego) < globalParameters.OPT_ADV_ACC_DIST
    take SetThrottleAction(globalParameters.OPT_ADV_THROTTLE)

AdvAgent = new Car at advSpawnPt,
    with heading advSpawnPt.heading,
    with regionContainedIn None,
    with behavior AdvBehavior()

#################################
# Spatial Relation              #
#################################
intersection = Uniform(*filter(lambda i: i.is4Way and i.isSignalized, network.intersections))

egoManeuver = Uniform(*filter(lambda m: m.type is ManeuverType.STRAIGHT, intersection.maneuvers))
egoInitLane = egoManeuver.startLane
egoTrajectory = [egoInitLane, egoManeuver.connectingLane, egoManeuver.endLane]
egoSpawnPt = new OrientedPoint in egoInitLane.centerline

advManeuver = Uniform(*filter(lambda m: m.type is ManeuverType.STRAIGHT, egoManeuver.conflictingManeuvers))
advInitLane = advManeuver.startLane
advTrajectory = [advInitLane, advManeuver.connectingLane, advManeuver.endLane]
advSpawnPt = new OrientedPoint in advInitLane.centerline

#################################
# Requirements and Restrictions #
#################################
monitor TrafficLights():
    freezeTrafficLights()
    while True:
        if withinDistanceToTrafficLight(ego, 100):
            setClosestTrafficLightStatus(ego, "green")
        if withinDistanceToTrafficLight(AdvAgent, 100):
            setClosestTrafficLightStatus(AdvAgent, "red")
        wait

require monitor TrafficLights()
require 30 <= (distance from egoSpawnPt to intersection) <= 40
require 5 <= (distance from advSpawnPt to intersection) <= 10