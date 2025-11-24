#################################
# DESCRIPTION                   #
#################################

description = "Ego vehicle is going straight at a 4-way intersection but a crossing forces the ego-vehicle to perform a collision avoidance maneuver."

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

EGO_INIT_DIST = [10, 15]
param EGO_SPEED = Range(7, 10)
param EGO_BRAKE = Range(0.5, 1.0)

ADV_INIT_DIST = [10, 15]
param ADV_SPEED = Range(7, 10)

SAFE_DIST = 20
INIT_DIST = 80
TERM_DIST = 70

#################################
# AGENT BEHAVIORS               #
#################################

behavior EgoBehavior(trajectory):
    try:
        do FollowTrajectoryBehavior(target_speed=globalParameters.EGO_SPEED,trajectory=trajectory)
    interrupt when withinDistanceToAnyObjs(self,SAFE_DIST):
        take SetBrakeAction(globalParameters.EGO_BRAKE)

behavior AdvBehavior(trajectory):
    do FollowTrajectoryBehavior(target_speed=globalParameters.ADV_SPEED,trajectory=trajectory)

#################################
# SPATIAL RELATIONS             #
#################################

intersection = Uniform(*filter(lambda i: i.is4Way, network.intersections))

egoInitLane = Uniform(*intersection.incomingLanes)
egoManeuver = Uniform(*filter(lambda i: i.type == ManeuverType.STRAIGHT, egoInitLane.maneuvers))
egoTrajectory = [egoManeuver.startLane, egoManeuver.connectingLane, egoManeuver.endLane]
egoSpawnPt = new OrientedPoint in egoManeuver.startLane.centerline

advManeuver = Uniform(*filter(lambda i: i.type == ManeuverType.STRAIGHT, egoManeuver.conflictingManeuvers))
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