#################################
# DESCRIPTION                   #
#################################

description = "Ego vehicle moves to the slower lane while the column of adversary vehicle passes."

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


param EGO_SPEED = Range(3, 5) 

param ADV_SPEED = Range(7, 10) #ADV2 nad ADV3 will have the same speed
param ADV1_DIST = Range(-25,-20)
param ADV2_DIST = globalParameters.ADV1_DIST + Range(-15,-10)
param ADV3_DIST = globalParameters.ADV2_DIST +Range(-15,-10)
param SAFE_DIST = 15

INIT_DIST = 50
TERM_DIST = 100

#################################
# AGENT BEHAVIORS               #
#################################

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

behavior AdversaryBehavior():
	do FollowLaneBehavior(target_speed=globalParameters.ADV_SPEED)

#################################
# SPATIAL RELATIONS             #
#################################

initLane = Uniform(*network.lanes)
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

adversary_3 = new Car following roadDirection for globalParameters.ADV3_DIST,
	with blueprint MODEL,
	with behavior AdversaryBehavior()

require (distance to intersection) > INIT_DIST
require (distance from adversary_1 to intersection) > INIT_DIST
require (distance from adversary_2 to intersection) > INIT_DIST
require (distance from adversary_3 to intersection) > INIT_DIST
terminate when (distance to egoSpawnPt) > TERM_DIST 

