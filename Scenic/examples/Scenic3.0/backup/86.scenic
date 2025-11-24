#################################
# DESCRIPTION                   #
#################################

description = "Ego vehicle goes left at 3-way intersection."

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
param EGO_SPEED = Range(7, 10)


TERM_DIST = 100

#################################
# AGENT BEHAVIORS               #
#################################

behavior EgoBehavior(trajectory):
	do FollowTrajectoryBehavior(target_speed=globalParameters.EGO_SPEED, trajectory=trajectory)
#################################
# SPATIAL RELATIONS             #
#################################

intersection = Uniform(*filter(lambda i: i.is3Way, network.intersections))

egoInitLane = Uniform(*intersection.incomingLanes)
egoManeuver = Uniform(*filter(lambda m: m.type is ManeuverType.LEFT_TURN, egoInitLane.maneuvers))
egoTrajectory = [egoInitLane, egoManeuver.connectingLane, egoManeuver.endLane]
egoSpawnPt = new OrientedPoint in egoInitLane.centerline


#################################
# SCENARIO SPECIFICATION        #
#################################

ego = new Car at egoSpawnPt,
	with blueprint MODEL,
	with behavior EgoBehavior(egoTrajectory)

require EGO_INIT_DIST[0] <= (distance to intersection) <= EGO_INIT_DIST[1]
terminate when (distance to egoSpawnPt) > TERM_DIST
