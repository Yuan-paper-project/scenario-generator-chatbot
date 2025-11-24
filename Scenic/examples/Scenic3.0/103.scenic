#################################
# DESCRIPTION                   #
#################################

description = "Ego vehicle moves to the faster lane and surpasses two adversary vehicles that were in its original lane."

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

param EGO_SPEED = Range(6, 8)

param ADV1_DIST = Range(20, 25)
param ADV2_DIST = globalParameters.ADV1_DIST + Range(15, 20)
param ADV_SPEED = Range(2, 4)

BYPASS_DIST = 15
INIT_DIST = 50
TERM_DIST = globalParameters.ADV2_DIST + 100

#################################
# AGENT BEHAVIORS               #
#################################

behavior EgoBehavior():
	try:
		do FollowLaneBehavior(target_speed=globalParameters.EGO_SPEED)
	interrupt when withinDistanceToAnyObjs(self, BYPASS_DIST):
		fasterLaneSec = self.laneSection.fasterLane
		do LaneChangeBehavior(
			laneSectionToSwitch=fasterLaneSec,
			target_speed=globalParameters.EGO_SPEED)
		do FollowLaneBehavior(target_speed=globalParameters.EGO_SPEED) 

behavior AdversaryBehavior():
	do FollowLaneBehavior(target_speed=globalParameters.ADV_SPEED)

#################################
# SPATIAL RELATIONS             #
#################################

initLane = Uniform(*filter(lambda lane:
	all([sec._laneToRight is not None for sec in lane.sections]),
	network.lanes))
egoSpawnPt = new OrientedPoint in initLane.centerline
egoLaneSecToSwitch = initLane.sectionAt(egoSpawnPt).laneToRight

#################################
# SCENARIO SPECIFICATION        #
#################################

ego = new Car at egoSpawnPt,
	with blueprint MODEL,
	with behavior EgoBehavior()

adversary_1 = new Car following roadDirection for globalParameters.ADV1_DIST,
	with blueprint MODEL,
	with behavior AdversaryBehavior()

adversary_2 = new Car following roadDirection for globalParameters.ADV2_DIST,
	with blueprint MODEL,
	with behavior AdversaryBehavior()

require (distance to intersection) > INIT_DIST
require (distance from adversary_1 to intersection) > INIT_DIST
require (distance from adversary_2 to intersection) > INIT_DIST

require always (adversary_1.laneSection._fasterLane is not None)
require always (adversary_2.laneSection._fasterLane is not None)

terminate when (distance to adversary_2) > TERM_DIST
