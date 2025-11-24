#################################
# Description
#################################

description = "Ego vehicle moves to the slower lane while the column of adversary vehicle passes."

#################################
# Header
#################################

param map = localPath('../../assets/maps/CARLA/Town05.xodr')
param carla_map = 'Town05'
model scenic.simulators.carla.model

MODEL = 'vehicle.mini.cooper_s_2021'

#################################
# Ego Behavior
#################################

param EGO_SPEED = Range(3, 5) 
param SAFE_DIST = 15

behavior EgoBehavior():
	try:
		do FollowLaneBehavior(target_speed=globalParameters.EGO_SPEED) 
	interrupt when withinDistanceToAnyObjs(self, globalParameters.SAFE_DIST):
		slowerLane = self.laneSection.slowerLane
		do LaneChangeBehavior(
				laneSectionToSwitch=slowerLane,
				target_speed=globalParameters.EGO_SPEED)
		do FollowLaneBehavior(
				target_speed=globalParameters.EGO_SPEED,
				laneToFollow=slowerLane.lane) \

#################################
# Adversarial Behavior
#################################

param ADV_SPEED = Range(7, 10) #ADV2 nad ADV3 will have the same speed

behavior AdversaryBehavior():
	do FollowLaneBehavior(target_speed=globalParameters.ADV_SPEED)

#################################
# Spatial Relation
#################################

initLane = Uniform(*network.lanes)
egoSpawnPt = new OrientedPoint in initLane.centerline
egoLaneSecToSwitch = initLane.sectionAt(egoSpawnPt).laneToRight

#################################
# Ego object
#################################

ego = new Car at egoSpawnPt,
	with blueprint MODEL,
	with behavior EgoBehavior()

#################################
# Adversarial object
#################################

param ADV1_DIST = Range(-25,-20)
param ADV2_DIST = globalParameters.ADV1_DIST + Range(-15,-10)
param ADV3_DIST = globalParameters.ADV2_DIST +Range(-15,-10)

adversary_1 = new Car following roadDirection for globalParameters.ADV1_DIST,
	with blueprint MODEL,
	with behavior AdversaryBehavior()

adversary_2 = new Car following roadDirection for globalParameters.ADV2_DIST,
	with blueprint MODEL,
	with behavior AdversaryBehavior()

adversary_3 = new Car following roadDirection for globalParameters.ADV3_DIST,
	with blueprint MODEL,
	with behavior AdversaryBehavior()

#################################
# Requirements and Restrictions
#################################

INIT_DIST = 50
TERM_DIST = 100

require (distance to intersection) > INIT_DIST
require (distance from adversary_1 to intersection) > INIT_DIST
require (distance from adversary_2 to intersection) > INIT_DIST
require (distance from adversary_3 to intersection) > INIT_DIST
terminate when (distance to egoSpawnPt) > TERM_DIST