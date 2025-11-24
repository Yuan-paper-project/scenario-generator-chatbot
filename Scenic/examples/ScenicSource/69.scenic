#################################
# DESCRIPTION                   #
#################################

description = "Ego vehicle goes straight at 3-way intersection. Adversary vehicle making a turn left must stop to avoid collision."

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

param EGO_SPEED = Range(9, 10)

behavior EgoBehavior(trajectory):
	do FollowTrajectoryBehavior(target_speed=globalParameters.EGO_SPEED, trajectory=trajectory)

#################################
# Adversarial Behavior          #
#################################

param ADV_SPEED = Range(3, 5)
param ADV_BRAKE = Range(0.5, 1.0)
SAFE_DIST = 20

behavior AdvBehavior(trajectory):
	try:
		do FollowTrajectoryBehavior(target_speed=globalParameters.ADV_SPEED, trajectory=trajectory)
	interrupt when withinDistanceToAnyObjs(self, SAFE_DIST):
		take SetBrakeAction(globalParameters.ADV_BRAKE)

#################################
# Spatial Relation              #
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
	with behavior AdvBehavior(advTrajectory)

#################################
# Requirements and Restrictions #
#################################

EGO_INIT_DIST = [20, 40]
ADV_INIT_DIST = [0, 20]
TERM_DIST = 70

require EGO_INIT_DIST[0] <= (distance to intersection) <= EGO_INIT_DIST[1]
require ADV_INIT_DIST[0] <= (distance from adversary to intersection) <= ADV_INIT_DIST[1]
terminate when (distance to egoSpawnPt) > TERM_DIST