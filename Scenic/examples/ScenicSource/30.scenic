#################################
# Description
#################################
description = "Ego vehicle makes a right turn at a an intersection while a pedestrian crosses the crosswalk on the left side."

#################################
# Header
#################################
param map = localPath('../../assets/maps/CARLA/Town05.xodr')
param carla_map = 'Town05'
model scenic.simulators.carla.model

MODEL = 'vehicle.mini.cooper_s_2021'

#################################
# Ego
#################################
param EGO_SPEED = Range(7, 10)
EGO_BRAKE = 1.0

behavior EgoBehavior(trajectory):
    do FollowTrajectoryBehavior(target_speed=globalParameters.EGO_SPEED, trajectory=trajectory)

ego = new Car at egoSpawnPt,
    with blueprint MODEL,
    with behavior EgoBehavior(egoTrajectory)

#################################
# Adversarial
#################################
PED_MIN_SPEED = 1.0
PED_THRESHOLD = 20

behavior PedestrianBehavior():
    do CrossingBehavior(ego, PED_MIN_SPEED, PED_THRESHOLD)

ped = new Pedestrian left of tempSpawnPt by 10,
    facing ego.heading,
    with regionContainedIn None,
    with behavior PedestrianBehavior()

#################################
# Spatial Relation
#################################
intersection = Uniform(*filter(lambda i: i.is4Way or i.is3Way, network.intersections))

egoManeuver = Uniform(*filter(lambda m: m.type is ManeuverType.RIGHT_TURN, intersection.maneuvers))
egoInitLane = egoManeuver.startLane
egoTrajectory = [egoInitLane, egoManeuver.connectingLane, egoManeuver.endLane]
egoSpawnPt = new OrientedPoint in egoInitLane.centerline

tempSpawnPt = egoInitLane.centerline[-1]

#################################
# Requirements and Restrictions
#################################
EGO_INIT_DIST = [20, 25]
param SAFETY_DIST = Range(10, 15)
CRASH_DIST = 5
TERM_DIST = 50

require EGO_INIT_DIST[0] <= (distance to intersection) <= EGO_INIT_DIST[1]
terminate when (distance to egoSpawnPt) > TERM_DIST