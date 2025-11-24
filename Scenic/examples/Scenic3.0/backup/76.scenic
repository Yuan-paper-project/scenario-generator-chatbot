#################################
# DESCRIPTION                   #
#################################

description = "Ego vehicle encounters a chain of debris in its lane. it moves the faster lane to bypass the debris and then returns to its original lane."

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

param EGO_SPEED = Range(7, 10)

BYPASS_DIST = [10, 20]
INIT_DIST = 50
TERM_DIST = 50

#################################
# AGENT BEHAVIORS               #
#################################

behavior EgoBehavior(speed=10):
	try:
		do FollowLaneBehavior(target_speed=globalParameters.EGO_SPEED)
	interrupt when withinDistanceToAnyObjs(self, BYPASS_DIST[0]):
		fasterLaneSec = self.laneSection.fasterLane
		do LaneChangeBehavior(
				laneSectionToSwitch=fasterLaneSec,
				target_speed=globalParameters.EGO_SPEED)
		do FollowLaneBehavior(
				target_speed=globalParameters.EGO_SPEED,
				laneToFollow=fasterLaneSec.lane) \
			until (distance to adversary) > BYPASS_DIST[1]
		slowerLaneSec = self.laneSection.slowerLane
		do LaneChangeBehavior(
				laneSectionToSwitch=slowerLaneSec,
				target_speed=globalParameters.EGO_SPEED)

#################################
# SPATIAL RELATIONS             #
#################################

lane = Uniform(*network.lanes)
egoSpawnPt = new OrientedPoint on lane.centerline

#################################
# SCENARIO SPECIFICATION        #
#################################

ego = new Car at egoSpawnPt,
    with blueprint MODEL,
    with behavior EgoBehavior()

debris1 = new Debris following roadDirection for Range(20, 25)
debris2 = new Debris following roadDirection from debris1 for Range(5, 10)
debris3 = new Debris following roadDirection from debris2 for Range(5, 10)

require (distance to intersection) > INIT_DIST
terminate when (distance from debris3 to ego) > 20 and (distance to egoSpawnPt) > TERM_DIST
require always (ego.laneSection._fasterLane is not None)
