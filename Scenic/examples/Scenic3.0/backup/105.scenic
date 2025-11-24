#################################
# DESCRIPTION                   #
#################################

description = "Adversary vehicle performs multiple lane changes to bypass Ego vehicle and two slow adversary vehicles."

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

param ADV1_DIST = Range(-15, -20)
param ADV2_DIST = Range(15, 20)
param ADV3_DIST = globalParameters.ADV2_DIST + Range(20, 25)

param EGO_SPEED = Range(3, 5) #ADV2 nad ADV3 will have the same speed
param ADV1_SPEED = Range(7, 10)

BYPASS_DIST = [20, 10]
INIT_DIST = 50
TERM_DIST = 100

#################################
# AGENT BEHAVIORS               #
#################################

behavior EgoBehavior():
	do FollowLaneBehavior(target_speed=globalParameters.EGO_SPEED)

behavior Adversary1Behavior():
	try:
		do FollowLaneBehavior(target_speed=globalParameters.ADV1_SPEED)
	interrupt when (distance to ego) < BYPASS_DIST[0]:
		newLaneSec = self.laneSection.laneToRight
		do LaneChangeBehavior(
			laneSectionToSwitch=newLaneSec,
			target_speed=globalParameters.ADV1_SPEED)
		do FollowLaneBehavior(target_speed=globalParameters.ADV1_SPEED) \
			until (distance to adversary_2) > BYPASS_DIST[1]
		newLaneSec = self.laneSection.laneToLeft
		do LaneChangeBehavior(
			laneSectionToSwitch=newLaneSec,
			target_speed=globalParameters.ADV1_SPEED)
		do FollowLaneBehavior(target_speed=globalParameters.ADV1_SPEED) \
			until (distance to adversary_3) > BYPASS_DIST[1]
		newLaneSec = self.laneSection.laneToRight
		do LaneChangeBehavior(
			laneSectionToSwitch=newLaneSec,
			target_speed=globalParameters.ADV1_SPEED)
		do FollowLaneBehavior(target_speed=globalParameters.ADV1_SPEED) 

behavior Adversary2Behavior():
	newLaneSec = self.laneSection.laneToRight
	do LaneChangeBehavior(
		laneSectionToSwitch=newLaneSec,
		target_speed=globalParameters.EGO_SPEED)
	do FollowLaneBehavior(target_speed=globalParameters.EGO_SPEED)

behavior Adversary3Behavior():
	do FollowLaneBehavior(target_speed=globalParameters.EGO_SPEED)

#################################
# SPATIAL RELATIONS             #
#################################

initLane = Uniform(*filter(lambda lane:all([sec._laneToRight is not None for sec in lane.sections]),network.lanes))
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

adversary_3 = new Car following roadDirection for globalParameters.ADV3_DIST,
	with blueprint MODEL,
	with behavior Adversary3Behavior()

require (distance to intersection) > INIT_DIST
require (distance from adversary_1 to intersection) > INIT_DIST
require (distance from adversary_2 to intersection) > INIT_DIST
require (distance from adversary_3 to intersection) > INIT_DIST
terminate when (distance to egoSpawnPt) > TERM_DIST