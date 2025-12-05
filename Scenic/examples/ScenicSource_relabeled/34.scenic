#################################
# Description                   #
#################################

description = "Ego vehicle overtakes one adversary vehicle but then slows down to the speed of the second adversary vehicle in the current lane."

#################################
# Header                        #
#################################

param map = localPath('../../assets/maps/CARLA/Town05.xodr')
param carla_map = 'Town05'
model scenic.simulators.carla.model

MODEL = 'vehicle.mini.cooper_s_2021'

#################################
# Ego                           #
#################################

param EGO_SPEED = Range(6, 8)
BYPASS_DIST = 15
param ADV_SPEED = Range(2, 4)

behavior EgoBehavior():
	try:
		do FollowLaneBehavior(target_speed=globalParameters.EGO_SPEED)
	interrupt when (distance to adversary_1) < BYPASS_DIST:
		newLaneSec = self.laneSection.laneToRight
		do LaneChangeBehavior(
			laneSectionToSwitch=newLaneSec,
			target_speed=globalParameters.EGO_SPEED)
	interrupt when (distance to adversary_2) < BYPASS_DIST:
		do FollowLaneBehavior(target_speed=globalParameters.ADV_SPEED)

ego = new Car at egoSpawnPt,
	with blueprint MODEL,
	with behavior EgoBehavior()

#################################
# Adversarial                   #
#################################

param ADV_SPEED = Range(2, 4)
param ADV1_DIST = Range(20, 25)

behavior Adversary1Behavior():
	do FollowLaneBehavior(target_speed=globalParameters.ADV_SPEED)

adversary_1 = new Car following roadDirection for globalParameters.ADV1_DIST,
	with blueprint MODEL,
	with behavior Adversary1Behavior()

#################################
# Adversarial                   #
#################################

param ADV_SPEED = Range(2, 4)
param ADV1_DIST = Range(20, 25)
param ADV2_DIST = globalParameters.ADV1_DIST + Range(15, 20)

behavior Adversary2Behavior():
	rightLaneSec = self.laneSection.laneToRight
	do LaneChangeBehavior(
		laneSectionToSwitch=rightLaneSec,
		target_speed=globalParameters.ADV_SPEED)
	do FollowLaneBehavior(target_speed=globalParameters.ADV_SPEED)

adversary_2 = new Car following roadDirection for globalParameters.ADV2_DIST,
	with blueprint MODEL,
	with behavior Adversary2Behavior()

#################################
# Spatial Relation              #
#################################

initLane = Uniform(*filter(lambda lane:
	all([sec._laneToRight is not None for sec in lane.sections]),
	network.lanes))
egoSpawnPt = new OrientedPoint in initLane.centerline
egoLaneSecToSwitch = initLane.sectionAt(egoSpawnPt).laneToRight

#################################
# Requirements and Restrictions #
#################################

param ADV1_DIST = Range(20, 25)
param ADV2_DIST = globalParameters.ADV1_DIST + Range(15, 20)

INIT_DIST = 50
TERM_DIST = globalParameters.ADV2_DIST + 100

require (distance to intersection) > INIT_DIST
require (distance from adversary_1 to intersection) > INIT_DIST
require (distance from adversary_2 to intersection) > INIT_DIST
terminate when (distance to egoSpawnPt) > TERM_DIST