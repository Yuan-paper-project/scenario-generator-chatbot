#################################
# Description                   #
#################################
description = "The ego attempts an unprotected left turn at an intersection while yielding to an oncoming car when the oncoming car veers erratically."

#################################
# Header                        #
#################################
Town = 'Town05'
param map = localPath(f'../../assets/maps/CARLA/{Town}.xodr')
param carla_map = Town
model scenic.simulators.carla.model
from scenic.domains.driving.controllers import *

EGO_MODEL = "vehicle.lincoln.mkz_2017"

#################################
# Ego                           #
#################################
param OPT_EGO_SPEED = Range(3, 5)
param OPT_EGO_YIELD_DIST = Range(20, 25)# Distance to adv at which ego must decide

behavior EgoBehavior():
    initialDir = egoSpawnPt.heading
    try:
        do FollowTrajectoryBehavior(trajectory=egoTrajectory, target_speed=globalParameters.OPT_EGO_SPEED)
    interrupt when (withinDistanceToAnyObjs(self, globalParameters.OPT_EGO_YIELD_DIST)):
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
param OPT_ADV_SPEED= Range(3, 6)
param OPT_ADV_DIST = Range(1, 5) # Distance in m for the adv to start its late turn

behavior AdvBehavior():
    do FollowLaneBehavior(target_speed=globalParameters.OPT_ADV_SPEED) until (distance from self to intersection < globalParameters.OPT_ADV_DIST)
    do AdvVeerBehavior()

behavior AdvVeerBehavior():
    K_P = 0.3
    K_D = 0.2
    K_I = 0.0
    dt = 0.1
    pid = PIDLateralController(K_P, K_D, K_I, dt)
    veer_amplitude = Range(1, 5)/10
    period = Range(1, 3)

    start_point = advStraightTrajectory[0].centerline[0]
    past_steer = 0.0
    while True:
        progress = distance from self to start_point
        cte = veer_amplitude * sin(progress / period)
        steer = pid.run_step(cte)
        take RegulatedControlAction(throttle=1.0, steer=steer, past_steer=past_steer)
        past_steer = steer
        wait

AdvAgent = new Car at advSpawnPt,
    with heading advSpawnPt.heading,
    with regionContainedIn None,
    with behavior AdvBehavior()

#################################
# Spatial Relation              #
#################################
param OPT_ADV_START_DIST = Range(30, 35)   # How far away the adv car starts

intersection = Uniform(*filter(lambda i: i.is4Way, network.intersections))

egoManeuver = Uniform(*filter(lambda m: m.type is ManeuverType.LEFT_TURN, intersection.maneuvers))
egoTrajectory = [egoManeuver.startLane, egoManeuver.connectingLane, egoManeuver.endLane]
egoTrajectoryLine = egoManeuver.startLane.centerline + egoManeuver.connectingLane.centerline + egoManeuver.endLane.centerline
egoInitLane = egoManeuver.startLane
egoSpawnPt = new OrientedPoint in egoInitLane.centerline

advLastMinuteManeuver = Uniform(*filter(lambda m: m.type is ManeuverType.RIGHT_TURN, intersection.maneuvers))
advStraightManeuver = Uniform(*filter(lambda m: m.type is ManeuverType.STRAIGHT, advLastMinuteManeuver.startLane.maneuvers))
advStraightTrajectory = [advStraightManeuver.startLane, advStraightManeuver.connectingLane, advStraightManeuver.endLane]
advLastMinuteTrajectory = [advLastMinuteManeuver.startLane, advLastMinuteManeuver.connectingLane, advLastMinuteManeuver.endLane]
advInitLane = advLastMinuteManeuver.startLane

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

require CONST_MIN_OPPOSITE_DEG < (egoDir - advDir) < CONST_MAX_OPPOSITE_DEG
require 30 <= (distance from egoSpawnPt to intersection) <= 40