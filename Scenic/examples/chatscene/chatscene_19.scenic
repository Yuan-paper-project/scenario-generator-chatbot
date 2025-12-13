#################################
# Description                   #
#################################
description = "The ego starts an unprotected left turn at an intersection while yielding to an leading oncoming car when the following oncoming car's throttle malfunctions, leading to an unexpected acceleration and forcing the ego to quickly decide wether to brake or accelerate."

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
param OPT_EGO_ACCELERATED_SPEED = globalParameters.OPT_EGO_SPEED + Uniform(2,3)
param OPT_EGO_YIELD_DIST = Range(8, 10)
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
param OPT_LEAD_SPEED = Range(2, 3)

LeadingCar = new Car at LeadingSpawnPt,
    with heading LeadingSpawnPt.heading,
    with regionContainedIn None,
    with behavior FollowLaneBehavior(globalParameters.OPT_LEAD_SPEED)

#################################
# Adversarial                   #
#################################
param OPT_ADV_SPEED_INITIAL = Range(2, 4)
param OPT_ADV_SPEED_ACCEL = Range(7, 12)
param OPT_ADV_TRIGGER_DIST = Range(18, 25)

behavior AdvBehavior():
    do FollowTrajectoryBehavior(trajectory=advTrajectory, target_speed=globalParameters.OPT_ADV_SPEED_INITIAL) until (distance from self to ego < globalParameters.OPT_ADV_TRIGGER_DIST)
    do FollowTrajectoryBehavior(trajectory=advTrajectory, target_speed=globalParameters.OPT_ADV_SPEED_ACCEL)

AdvAgent = new Car at advSpawnPt,
    with heading advSpawnPt.heading,
    with regionContainedIn None,
    with behavior AdvBehavior()

#################################
# Spatial Relation              #
#################################
param OPT_ADV_START_DIST = Range(45, 60)
param OPT_LEADING_START_DIST = Range(5,10)

intersection = Uniform(*filter(lambda i: i.is4Way and i.isSignalized, network.intersections))
egoManeuver = Uniform(*filter(lambda m: m.type is ManeuverType.LEFT_TURN, intersection.maneuvers))
egoTrajectory = [egoManeuver.startLane, egoManeuver.connectingLane, egoManeuver.endLane]
egoInitLane = egoManeuver.startLane
egoSpawnPt = new OrientedPoint in egoInitLane.centerline

advManeuver = Uniform(*filter(lambda m: m.type is ManeuverType.STRAIGHT, egoManeuver.conflictingManeuvers))
advTrajectory = [advManeuver.startLane, advManeuver.connectingLane, advManeuver.endLane]
advInitLane = advManeuver.startLane

advSpawnPt = new OrientedPoint following advInitLane.orientation from advInitLane.centerline.end for -globalParameters.OPT_ADV_START_DIST

LeadingSpawnPt = new OrientedPoint following advInitLane.orientation from advInitLane.centerline.end for -globalParameters.OPT_LEADING_START_DIST

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
        if withinDistanceToTrafficLight(LeadingCar, 100):
            setClosestTrafficLightStatus(LeadingCar, "green")
        wait

require CONST_MIN_OPPOSITE_DEG < (egoDir - advDir) < CONST_MAX_OPPOSITE_DEG
require monitor TrafficLights()
require 30 <= (distance from egoSpawnPt to intersection) <= 40