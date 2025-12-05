#################################
# Description                   #
#################################

description = "Ego vehicle follows a lead vehicle. They makes a right turn at 3-way intersection and must suddenly stop to avoid collision when adversary vehicle from lateral lane continues straight."

#################################
# Header                        #
#################################

param map = localPath('../../assets/maps/CARLA/Town05.xodr')
param carla_map = 'Town05'
model scenic.simulators.carla.model

# Shared constants
MODEL = 'vehicle.mini.cooper_s_2021'

#################################
# Ego                           #
#################################

# Parameters for Ego Behavior
param EGO_SPEED = Range(3, 5)
param EGO_BRAKE = Range(0.5, 1.0)
SAFE_DIST = 20

behavior EgoBehavior(trajectory):
	try:
		do FollowTrajectoryBehavior(target_speed=globalParameters.EGO_SPEED, trajectory=trajectory)
	interrupt when withinDistanceToAnyObjs(self, SAFE_DIST):
		take SetBrakeAction(globalParameters.EGO_BRAKE)

ego = new Car at egoSpawnPt,
	with blueprint MODEL,
	with behavior EgoBehavior(egoTrajectory)

#################################
# Ego                           #
#################################

# Parameters for Ego Behavior
param EGO_SPEED = Range(3, 5)
param EGO_BRAKE = Range(0.5, 1.0)
SAFE_DIST = 20
# Parameters for Lead object
LEAD_DIST = Range(5,10)

behavior EgoBehavior(trajectory):
	try:
		do FollowTrajectoryBehavior(target_speed=globalParameters.EGO_SPEED, trajectory=trajectory)
	interrupt when withinDistanceToAnyObjs(self, SAFE_DIST):
		take SetBrakeAction(globalParameters.EGO_BRAKE)

lead = new Car following roadDirection for LEAD_DIST,
	with blueprint MODEL,
	with behavior EgoBehavior(egoTrajectory)

#################################
# Adversarial                   #
#################################

param ADV_SPEED = Range(3, 5)

behavior AdversaryBehavior(trajectory):
	do FollowTrajectoryBehavior(target_speed=globalParameters.ADV_SPEED, trajectory=trajectory)

adversary = new Car at advSpawnPt,
	with blueprint MODEL,
	with behavior AdversaryBehavior(advTrajectory)

#################################
# Spatial Relation              #
#################################

intersection = Uniform(*filter(lambda i: i.is3Way, network.intersections))

egoInitLane = Uniform(*intersection.incomingLanes)
egoManeuver = Uniform(*filter(lambda m: m.type is ManeuverType.RIGHT_TURN, egoInitLane.maneuvers))
egoTrajectory = [egoInitLane, egoManeuver.connectingLane, egoManeuver.endLane]
egoSpawnPt = new OrientedPoint in egoInitLane.centerline

advManeuver = Uniform(*filter(lambda m: m.type is ManeuverType.STRAIGHT, egoManeuver.conflictingManeuvers))
advInitLane = advManeuver.startLane
advTrajectory = [advInitLane, advManeuver.connectingLane, advManeuver.endLane]
advSpawnPt = new OrientedPoint in advInitLane.centerline

#################################
# Requirements and Restrictions #
#################################

EGO_INIT_DIST = [20, 40]
ADV_INIT_DIST = [0, 20]
TERM_DIST = 100

require EGO_INIT_DIST[0] <= (distance to intersection) <= EGO_INIT_DIST[1]
require ADV_INIT_DIST[0] <= (distance from adversary to intersection) <= ADV_INIT_DIST[1]
terminate when (distance to egoSpawnPt) > TERM_DIST