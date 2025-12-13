#################################
# Description                   #
#################################
description = "The ego vehicle is moving straight through the intersection; the adversarial agent, initially on the right incoming lane, runs the red light and makes an abrupt right turn, forcing the ego vehicle to perform a collision avoidance maneuver."

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
param OPT_EGO_SPEED = Range(3, 6)
param OPT_COLLISION_AVOID_DIST = Range(8, 12)

behavior EgoBehavior():
    try:
        do FollowTrajectoryBehavior(target_speed=globalParameters.OPT_EGO_SPEED, trajectory=egoTrajectory)
    interrupt when (withinDistanceToObjsInLane(self, globalParameters.OPT_COLLISION_AVOID_DIST)):
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
param OPT_ADV_SPEED = Range(3, 6)
param OPT_ADV_DISTANCE = Range(40, 50)

behavior WaitBehavior():
    while True:
        wait

behavior AdvBehavior():
    do WaitBehavior() until (distance from self to ego) < globalParameters.OPT_ADV_DISTANCE
    do FollowTrajectoryBehavior(globalParameters.OPT_ADV_SPEED, advTrajectory) 
    do FollowLaneBehavior(target_speed=globalParameters.OPT_ADV_SPEED) 

AdvAgent = new Car at advSpawnPt,
    with regionContainedIn None,
    with blueprint EGO_MODEL,
    with behavior AdvBehavior()
       
#################################
# Spatial Relation              #
#################################

intersection = Uniform(*filter(lambda i: i.is4Way and i.isSignalized, network.intersections))

egoManeuver = Uniform(*filter(lambda m: m.type is ManeuverType.STRAIGHT, intersection.maneuvers))
egoInitLane = egoManeuver.startLane
egoTrajectory = [egoInitLane, egoManeuver.connectingLane, egoManeuver.endLane]
egoSpawnPt = new OrientedPoint in egoInitLane.centerline

advManeuver = Uniform(*filter(lambda m: m.type is ManeuverType.RIGHT_TURN, egoManeuver.conflictingManeuvers) )
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
require 10 <= (distance from advSpawnPt to intersection) <= 20