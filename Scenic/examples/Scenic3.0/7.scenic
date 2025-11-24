#################################
# DESCRIPTION                   #
#################################

description = "Ego vehicle is performing a maneuver at a 4-way intersection, yielding to adversary vehicle performing a conflicting maneuver."

#################################
# MAP AND MODEL                 #
#################################

param map = localPath('../../assets/maps/CARLA/Town05.xodr')
param carla_map = 'Town05'
model scenic.simulators.carla.model

#################################
# CONSTANTS                     #
#################################

MODEL = 'vehicle.mini.cooper_s_2021'

EGO_INIT_DIST = [20, 25]
param EGO_SPEED = Range(7, 10)
param EGO_BRAKE = Range(0.5, 1.0)

ADV_INIT_DIST = [15, 20]
param ADV_SPEED = Range(7, 10)

SAFE_DIST = 20
INIT_DIST = 80
TERM_DIST = 70

#################################
# AGENT BEHAVIORS               #
#################################

behavior AdvBehavior(trajectory):
    do FollowTrajectoryBehavior(target_speed=globalParameters.EGO_SPEED,trajectory=trajectory)

behavior EgoBehavior(trajectory):
    try:
        do FollowTrajectoryBehavior(target_speed=globalParameters.EGO_SPEED,trajectory=trajectory)
    interrupt when withinDistanceToAnyObjs(self, SAFE_DIST):
        take SetBrakeAction(globalParameters.EGO_BRAKE)

#################################
# SPATIAL RELATIONS             #
#################################

intersection = Uniform(*filter(lambda i: i.is4Way, network.intersections))

egoInitLane = Uniform(*intersection.incomingLanes)
egoManeuver = Uniform(*egoInitLane.maneuvers)
egoTrajectory = [egoManeuver.startLane, egoManeuver.connectingLane, egoManeuver.endLane]
egoSpawnPt = new OrientedPoint in egoManeuver.startLane.centerline

advManeuver = Uniform(*egoManeuver.conflictingManeuvers)
advTrajectory = [advManeuver.startLane, advManeuver.connectingLane, advManeuver.endLane]
advSpawnPt = new OrientedPoint in advManeuver.startLane.centerline

#################################
# SCENARIO SPECIFICATION        #
#################################

ego = new Car at egoSpawnPt,
    with blueprint MODEL,
    with behavior EgoBehavior(egoTrajectory)

adv = new Car at advSpawnPt,
    with blueprint MODEL,
    with behavior AdvBehavior(advTrajectory)

require EGO_INIT_DIST[0] <= (distance to intersection) <= EGO_INIT_DIST[1]
require ADV_INIT_DIST[0] <= (distance from adv to intersection) <= ADV_INIT_DIST[1]
terminate when (distance to egoSpawnPt) > TERM_DIST