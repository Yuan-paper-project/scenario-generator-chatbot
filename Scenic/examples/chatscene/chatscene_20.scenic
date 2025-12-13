#################################
# Description                   #
#################################
description = "The ego attempts an unprotected left turn at an intersection while yielding to an oncoming car when the oncoming car suddenly brakes, necessitating the ego to rapidly reassess the situation and wait to complete the turn."

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
param OPT_EGO_ACCELERATED_SPEED = globalParameters.OPT_EGO_SPEED + Uniform(2,3)
param OPT_EGO_YIELD_DIST = Range(8, 10) # Distance to adv at which ego must decide
OPT_EGO_DECISION_DEGREE = 35 deg

behavior EgoBehavior():
    initialDir = egoSpawnPt.heading
    try:
        do FollowTrajectoryBehavior(trajectory=egoTrajectory, target_speed=globalParameters.OPT_EGO_SPEED)
    interrupt when (self.distanceToClosest(Car) < globalParameters.OPT_EGO_YIELD_DIST):
        currentDir = self.heading
        if (abs(currentDir-initialDir) < OPT_EGO_DECISION_DEGREE):
            take SetThrottleAction(0)
            take SetBrakeAction(1)
        else:
            do FollowTrajectoryBehavior(trajectory=egoTrajectory,target_speed=globalParameters.OPT_EGO_ACCELERATED_SPEED)
            abort
    terminate

ego = new Car at egoSpawnPt,
    with regionContainedIn None,
    with blueprint EGO_MODEL,
    with behavior EgoBehavior()

#################################
# Adversarial                   #
#################################
param OPT_ADV_SPEED= Range(3, 6)  # Oncoming car starts slow
param OPT_ADV_WAIT_SEC = Range(1, 3)  # Time the adv waits before braking
OPT_ADV_TRIGGER_DIST = 1

behavior WaitBehavior():
    while True:
        wait

behavior AdvBehavior():
    do FollowTrajectoryBehavior(trajectory=advTrajectory, target_speed=globalParameters.OPT_ADV_SPEED) until (distance from self to egoTrajectoryLine < OPT_ADV_TRIGGER_DIST)
    take SetThrottleAction(0)  
    take SetBrakeAction(1)
    do WaitBehavior() for globalParameters.OPT_ADV_WAIT_SEC seconds
    do FollowTrajectoryBehavior(trajectory=advTrajectory, target_speed=globalParameters.OPT_ADV_SPEED) 

AdvAgent = new Car at advSpawnPt,
    with heading advSpawnPt.heading,
    with regionContainedIn None,
    with behavior AdvBehavior()

#################################
# Spatial Relation              #
#################################
param OPT_ADV_START_DIST = Range(30, 50)   # How far away the adv car starts

intersection = Uniform(*filter(lambda i: i.is4Way and i.isSignalized, network.intersections))

egoManeuver = Uniform(*filter(lambda m: m.type is ManeuverType.LEFT_TURN, intersection.maneuvers))
egoTrajectory = [egoManeuver.startLane, egoManeuver.connectingLane, egoManeuver.endLane]
egoTrajectoryLine = egoManeuver.startLane.centerline + egoManeuver.connectingLane.centerline + egoManeuver.endLane.centerline
egoInitLane = egoManeuver.startLane
egoSpawnPt = new OrientedPoint in egoInitLane.centerline

advManeuver = Uniform(*filter(lambda m: m.type is ManeuverType.STRAIGHT, egoManeuver.conflictingManeuvers))
advTrajectory = [advManeuver.startLane, advManeuver.connectingLane, advManeuver.endLane]
advInitLane = advManeuver.startLane

advSpawnPt = new OrientedPoint following advInitLane.orientation from advInitLane.centerline.end for -globalParameters.OPT_ADV_START_DIST

advDir = advSpawnPt.heading
egoDir = egoSpawnPt.heading

#################################
# Requirements and Restrictions #
#################################
CONST_OPPOSITE_DEG = 180 deg
CONST_TOL_DEG = 20 deg
CONST_MIN_OPPOSITE_DEG = CONST_OPPOSITE_DEG - CONST_TOL_DEG
CONST_MAX_OPPOSITE_DEG = CONST_OPPOSITE_DEG + CONST_TOL_DEG

monitor TrafficLights():
    freezeTrafficLights()
    while True:
        if withinDistanceToTrafficLight(ego, 100):
            setClosestTrafficLightStatus(ego, "green")
        if withinDistanceToTrafficLight(AdvAgent, 100):
            setClosestTrafficLightStatus(AdvAgent, "green")
        wait

require CONST_MIN_OPPOSITE_DEG < (egoDir - advDir) < CONST_MAX_OPPOSITE_DEG
require monitor TrafficLights()
require 30 <= (distance from egoSpawnPt to intersection) <= 40