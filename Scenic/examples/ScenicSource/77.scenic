#################################
# Description                   #
#################################

description = "Ego vehicle makes a left turn at 4-way intersection and must suddenly stop to avoid collision when adversary vehicle from opposite lane goes straight."

#################################
# Header                        #
#################################

param map = localPath('../../assets/maps/CARLA/Town05.xodr')
param carla_map = 'Town05'
model scenic.simulators.carla.model

MODEL = 'vehicle.mini.cooper_s_2021'

#################################
# Ego Behavior                  #
#################################

param EGO_SPEED = Range(7, 10)
param EGO_BRAKE = Range(0.5, 1.0)
SAFE_DIST = 15
CRASH_DIST = 5

behavior EgoBehavior(trajectory):
	try:
		do FollowTrajectoryBehavior(target_speed=globalParameters.EGO_SPEED, trajectory=trajectory)
	interrupt when withinDistanceToAnyObjs(self, SAFE_DIST):
		take SetBrakeAction(globalParameters.EGO_BRAKE)
	interrupt when withinDistanceToAnyObjs(self, CRASH_DIST):
		terminate

#################################
# Adversarial Behavior          #
#################################

param ADV_SPEED = Range(7, 10)

behavior AdversaryBehavior(trajectory):
	do FollowTrajectoryBehavior(target_speed=globalParameters.ADV_SPEED, trajectory=trajectory)

#################################
# Spatial Relation              #
#################################

intersection = Uniform(*filter(lambda i: i.is4Way, network.intersections))

advInitLane = Uniform(*intersection.incomingLanes)
advManeuver = Uniform(*filter(lambda m: m.type is ManeuverType.STRAIGHT, advInitLane.maneuvers))
advTrajectory = [advInitLane, advManeuver.connectingLane, advManeuver.endLane]
advSpawnPt = new OrientedPoint in advInitLane.centerline

egoInitLane = Uniform(*filter(lambda m:m.type is ManeuverType.STRAIGHT,advManeuver.reverseManeuvers)).startLane
egoManeuver = Uniform(*filter(lambda m: m.type is ManeuverType.LEFT_TURN, egoInitLane.maneuvers))
egoTrajectory = [egoInitLane, egoManeuver.connectingLane, egoManeuver.endLane]
egoSpawnPt = new OrientedPoint in egoInitLane.centerline

#################################
# Ego object                    #
#################################


ego = new Car at egoSpawnPt,
	with blueprint MODEL,
	with behavior EgoBehavior(egoTrajectory)

#################################
# Adversarial object            #
#################################

adversary = new Car at advSpawnPt,
	with blueprint MODEL,
	with behavior AdversaryBehavior(advTrajectory)

#################################
# Requirements and Restrictions #
#################################

TERM_DIST = 70
EGO_INIT_DIST = [20, 25]
ADV_INIT_DIST = [15, 20]

require EGO_INIT_DIST[0] <= (distance to intersection) <= EGO_INIT_DIST[1]
require ADV_INIT_DIST[0] <= (distance from adversary to intersection) <= ADV_INIT_DIST[1]
terminate when (distance to egoSpawnPt) > TERM_DIST