#################################
# DESCRIPTION                   #
#################################

description = "Ego vehicle following the other vehicle in front goes straight at 4-way intersection. The other vehicle and an ego vehicle must suddenly stop to avoid collision when adversary vehicle from opposite lane makes a left turn."

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

EGO_INIT_DIST = [30, 35]
param EGO_SPEED = Range(3, 5)
param EGO_BRAKE = Range(0.5, 1.0)

ADV_INIT_DIST = [15, 20]
param ADV_SPEED = Range(3, 5)

param OTHER_DIST = Range(10, 15)

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

intersection = Uniform(*filter(lambda i: i.is4Way, network.intersections))

egoInitLane = Uniform(*intersection.incomingLanes)
egoManeuver = Uniform(*filter(lambda m: m.type is ManeuverType.STRAIGHT, egoInitLane.maneuvers))
egoTrajectory = [egoInitLane, egoManeuver.connectingLane, egoManeuver.endLane]
egoSpawnPt = new OrientedPoint in egoInitLane.centerline

advInitLane = Uniform(*filter(lambda m:m.type is ManeuverType.STRAIGHT,egoManeuver.reverseManeuvers)).startLane
advManeuver = Uniform(*filter(lambda m: m.type is ManeuverType.LEFT_TURN, advInitLane.maneuvers))
advTrajectory = [advInitLane, advManeuver.connectingLane, advManeuver.endLane]
advSpawnPt = new OrientedPoint in advInitLane.centerline

#################################
# SCENARIO SPECIFICATION        #
#################################

ego = new Car at egoSpawnPt,
	with blueprint MODEL,
	with behavior EgoBehavior(egoTrajectory)

other = new Car following roadDirection for globalParameters.OTHER_DIST,
	with blueprint MODEL,
	with behavior EgoBehavior(egoTrajectory)

adversary = new Car at advSpawnPt,
	with blueprint MODEL,
	with behavior AdversaryBehavior(advTrajectory)

require EGO_INIT_DIST[0] <= (distance to intersection) <= EGO_INIT_DIST[1]
require ADV_INIT_DIST[0] <= (distance from adversary to intersection) <= ADV_INIT_DIST[1]
terminate when (distance to egoSpawnPt) > TERM_DIST
