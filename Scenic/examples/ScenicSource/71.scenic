#################################
# Description                   #
#################################
description = "Ego vehicle is performing a right turn at a 4-way intersection, yielding to crossing traffic."

#################################
# Header                        #
#################################
param map = localPath('../../assets/maps/CARLA/Town05.xodr')
param carla_map = 'Town05'
model scenic.simulators.carla.model

MODEL = 'vehicle.mini.cooper_s_2021'

#################################
# Ego                           #
#################################
param EGO_SPEED = Range(7, 10)
param EGO_BRAKE = Range(0.5, 1.0)
SAFE_DIST = 20

behavior EgoBehavior(trajectory):
    try :
        do FollowTrajectoryBehavior(target_speed=globalParameters.EGO_SPEED,trajectory=trajectory)
    interrupt when withinDistanceToAnyObjs(self, SAFE_DIST):
        take SetBrakeAction(globalParameters.EGO_BRAKE)

ego = new Car at egoSpawnPt,
    with blueprint MODEL,
    with behavior EgoBehavior(egoTrajectory)

#################################
# Adversarial                   #
#################################
param ADV_SPEED = Range(7, 10)

behavior AdvBehavior(trajectory):
    do FollowTrajectoryBehavior(target_speed=globalParameters.ADV_SPEED, trajectory=trajectory)

adv = new Car at advSpawnPt,
    with blueprint MODEL,
    with behavior AdvBehavior(advTrajectory)

#################################
# Spatial Relation              #
#################################
intersection = Uniform(*filter(lambda i: i.is4Way, network.intersections))

advInitLane = Uniform(*intersection.incomingLanes)
advManeuver = Uniform(*filter(lambda i: i.type == ManeuverType.STRAIGHT, advInitLane.maneuvers))
advTrajectory = [advManeuver.startLane, advManeuver.connectingLane, advManeuver.endLane]
advSpawnPt = new OrientedPoint in advManeuver.startLane.centerline

egoManeuver = Uniform(*filter(lambda i: i.type == ManeuverType.RIGHT_TURN, advManeuver.conflictingManeuvers))
egoTrajectory = [egoManeuver.startLane, egoManeuver.connectingLane, egoManeuver.endLane]
egoSpawnPt = new OrientedPoint in egoManeuver.startLane.centerline

#################################
# Requirements and Restrictions #
#################################
EGO_INIT_DIST = [10, 15]
ADV_INIT_DIST = [10, 15]
TERM_DIST = 70

require EGO_INIT_DIST[0] <= (distance to intersection) <= EGO_INIT_DIST[1]
require ADV_INIT_DIST[0] <= (distance from adv to intersection) <= ADV_INIT_DIST[1]
terminate when (distance to egoSpawnPt) > TERM_DIST