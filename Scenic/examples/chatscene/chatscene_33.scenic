#################################
# Description                   #
#################################
description = "The ego vehicle is entering the intersection; the adversarial vehicle comes from the opposite direction and turns left and stops, causing a near collision with the ego vehicle."

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
param OPT_EGO_SPEED = Range (1, 5)
param OPT_BRAKE_DISTANCE = Range(5, 8)  # Distance at which the ego vehicle begins to brake

behavior EgoBehavior():
    try:
        do FollowTrajectoryBehavior(trajectory=egoTrajectory, target_speed=globalParameters.OPT_EGO_SPEED)
    interrupt when (withinDistanceToObjsInLane(ego, globalParameters.OPT_BRAKE_DISTANCE)):
        take SetThrottleAction(0)  # Ensure no acceleration during braking
        take SetBrakeAction(1)  # Brake to avoid collision
        abort
    terminate

ego = new Car at egoSpawnPt,
    with regionContainedIn None,
    with blueprint EGO_MODEL,
    with behavior EgoBehavior()

#################################
# Adversarial                   #
#################################
param OPT_ADV_DISTANCE = Range(10, 20)/10
param OPT_EGO_SPEED = Range (1, 5)
param OPT_ADV_SPEED = globalParameters.OPT_EGO_SPEED * Range(10, 15)/10

behavior AdvBehavior():
    do FollowTrajectoryBehavior(trajectory=advTrajectory, target_speed=globalParameters.OPT_ADV_SPEED) until (distance from self to egoTrajectoryLine <= globalParameters.OPT_ADV_DISTANCE)
    take SetThrottleAction(0)
    take SetBrakeAction(1)

AdvAgent = new Car at advSpawnPt,
    with heading advSpawnPt.heading,
    with regionContainedIn None,
    with behavior AdvBehavior()

#################################
# Spatial Relation              #
#################################
intersection = Uniform(*filter(lambda i: i.is4Way and i.isSignalized, network.intersections))

advManeuver = Uniform(*filter(lambda m: m.type is ManeuverType.LEFT_TURN, intersection.maneuvers))
egoManeuver = Uniform(*advManeuver.conflictingManeuvers)

advInitLane = advManeuver.startLane
advSpawnPt = new OrientedPoint in advInitLane.centerline
advTrajectory = [advManeuver.startLane, advManeuver.connectingLane, advManeuver.endLane]

egoTrajectory = [egoManeuver.startLane, egoManeuver.connectingLane, egoManeuver.endLane]
egoTrajectoryLine = egoManeuver.startLane.centerline + egoManeuver.connectingLane.centerline + egoManeuver.endLane.centerline
egoInitLane = egoManeuver.startLane

egoSpawnPt = new OrientedPoint in egoInitLane.centerline

egoDir = egoSpawnPt.heading
advDir = advSpawnPt.heading

#################################
# Requirements and Restrictions #
#################################
CONST_OPPOSITE_DEG = 180 deg
CONST_TOL_DEG = 20 deg
CONST_MIN_OPPOSITE_DEG = CONST_OPPOSITE_DEG - CONST_TOL_DEG
CONST_MAX_OPPOSITE_DEG = CONST_OPPOSITE_DEG + CONST_TOL_DEG

require CONST_MIN_OPPOSITE_DEG < (egoDir - advDir) < CONST_MAX_OPPOSITE_DEG
require 30 <= (distance from egoSpawnPt to intersection) <= 40
require 10 <= (distance from advSpawnPt to intersection) <= 20