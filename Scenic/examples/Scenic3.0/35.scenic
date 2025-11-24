#################################
# DESCRIPTION                   #
#################################

description = "Ego vehicle overtakes one adversary vehicle but then performs an energency brake as there is the second adversary in ego vehicle in the same lane. After this, Ego vehicle starts following the second adversary vehicle in the same speed."

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
param EGO_BRAKE = Range(0.7, 1.0)

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
	interrupt when (distance to adversary_1) < BYPASS_DIST:
		newLaneSec = self.laneSection.laneToRight
		do LaneChangeBehavior(
			laneSectionToSwitch=newLaneSec,
			target_speed=globalParameters.EGO_SPEED)
	interrupt when (distance to adversary_2) < BYPASS_DIST:
		take SetBrakeAction(globalParameters.EGO_BRAKE)
		do FollowLaneBehavior(target_speed=globalParameters.ADV_SPEED) 

behavior Adversary1Behavior():
	do FollowLaneBehavior(target_speed=globalParameters.ADV_SPEED)

behavior Adversary2Behavior():
	rightLaneSec = self.laneSection.laneToRight
	do LaneChangeBehavior(
		laneSectionToSwitch=rightLaneSec,
		target_speed=globalParameters.ADV_SPEED)
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
	with behavior Adversary1Behavior()

adversary_2 = new Car following roadDirection for globalParameters.ADV2_DIST,
	with blueprint MODEL,
	with behavior Adversary2Behavior()

require (distance to intersection) > INIT_DIST
require (distance from adversary_1 to intersection) > INIT_DIST
require (distance from adversary_2 to intersection) > INIT_DIST
terminate when (distance to egoSpawnPt) > TERM_DIST