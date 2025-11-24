#################################
# description                   #
#################################

description = "Ego vehicle makes a left or a right turn at 4-way intersection. Adversary vehicle from lateral lane makes a left turn."

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

behavior EgoBehavior(trajectory):
	do FollowTrajectoryBehavior(target_speed=globalParameters.EGO_SPEED, trajectory=trajectory)

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

egoInitLane = Uniform(*intersection.incomingLanes)
egoManeuver = Uniform(*filter(lambda m:m.type in (ManeuverType.LEFT_TURN, ManeuverType.RIGHT_TURN),egoInitLane.maneuvers))
egoTrajectory = [egoInitLane, egoManeuver.connectingLane, egoManeuver.endLane]
egoSpawnPt = new OrientedPoint in egoInitLane.centerline

advInitLane = Uniform(*filter(lambda m:m.type is ManeuverType.STRAIGHT,Uniform(*filter(lambda m: m.type is ManeuverType.STRAIGHT, egoInitLane.maneuvers)).conflictingManeuvers)).startLane
advManeuver = Uniform(*filter(lambda m: m.type is ManeuverType.RIGHT_TURN, advInitLane.maneuvers))
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
	with behavior AdversaryBehavior(advTrajectory)

#################################
# Requirements and Restrictions #
#################################

EGO_INIT_DIST = [20, 25]
ADV_INIT_DIST = [15, 20]
TERM_DIST = 100

require EGO_INIT_DIST[0] <= (distance to intersection) <= EGO_INIT_DIST[1]
require ADV_INIT_DIST[0] <= (distance from adversary to intersection) <= ADV_INIT_DIST[1]
terminate when (distance to egoSpawnPt) > TERM_DIST