#################################
# DESCRIPTION                   #
#################################

description = "Ego vehicle goes straight at 3-way intersection and must suddenly stop to avoid collision when adversary vehicle makes a left turn. Ego vehicle only starts to move when adversary vehicle leaves the intersection."

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

EGO_INIT_DIST = [20, 40]
param EGO_SPEED = Range(9, 10)
param EGO_BRAKE = Range(0.5, 1.0)

ADV_INIT_DIST = [0, 20]
param ADV_SPEED = Range(5, 7)

SAFE_DIST = 20
TERM_DIST = 100

#################################
# AGENT BEHAVIORS               #
#################################

behavior EgoBehavior(trajectory):
	try:
		do FollowTrajectoryBehavior(target_speed=globalParameters.EGO_SPEED, trajectory=trajectory)
	interrupt when withinDistanceToAnyObjs(self, SAFE_DIST):
		take SetBrakeAction(globalParameters.EGO_BRAKE)

behavior AdversaryBehavior(trajectory):
	do FollowTrajectoryBehavior(target_speed=globalParameters.ADV_SPEED, trajectory=trajectory)

#################################
# SPATIAL RELATIONS             #
#################################

intersection = Uniform(*filter(lambda i: i.is3Way, network.intersections))

egoInitLane = Uniform(*intersection.incomingLanes)
egoManeuver = Uniform(*filter(lambda m: m.type is ManeuverType.STRAIGHT, egoInitLane.maneuvers))
egoTrajectory = [egoInitLane, egoManeuver.connectingLane, egoManeuver.endLane]
egoSpawnPt = new OrientedPoint in egoInitLane.centerline

advInitLane = Uniform(*filter(lambda m: m.type is ManeuverType.STRAIGHT,egoManeuver.reverseManeuvers)).startLane
advManeuver = Uniform(*filter(lambda m: m.type is ManeuverType.LEFT_TURN, advInitLane.maneuvers))
advTrajectory = [advInitLane, advManeuver.connectingLane, advManeuver.endLane]
advSpawnPt = new OrientedPoint in advInitLane.centerline

#################################
# SCENARIO SPECIFICATION        #
#################################

ego = new Car at egoSpawnPt,
	with blueprint MODEL,
	with behavior EgoBehavior(egoTrajectory)

adversary = new Car at advSpawnPt,
	with blueprint MODEL,
	with behavior AdversaryBehavior(advTrajectory)

require EGO_INIT_DIST[0] <= (distance to intersection) <= EGO_INIT_DIST[1]
require ADV_INIT_DIST[0] <= (distance from adversary to intersection) <= ADV_INIT_DIST[1]
terminate when (distance to egoSpawnPt) > TERM_DIST
