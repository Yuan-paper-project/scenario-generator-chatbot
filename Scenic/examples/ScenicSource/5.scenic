#################################
# Description                   #
#################################
description = "Ego vehicle performs multiple lane changes to bypass three slow adversary vehicles."

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
BYPASS_DIST = 15

behavior EgoBehavior():
	try:
		do FollowLaneBehavior(target_speed=globalParameters.EGO_SPEED)
	interrupt when (distance to adversary_1) < BYPASS_DIST:
		newLaneSec = self.laneSection.laneToRight
		do LaneChangeBehavior(
			laneSectionToSwitch=newLaneSec,
			target_speed=globalParameters.EGO_SPEED)
	interrupt when (distance to adversary_2) < BYPASS_DIST:
		newLaneSec = self.laneSection.laneToLeft
		do LaneChangeBehavior(
			laneSectionToSwitch=newLaneSec,
			target_speed=globalParameters.EGO_SPEED)
	interrupt when (distance to adversary_3) < BYPASS_DIST:
		newLaneSec = self.laneSection.laneToRight
		do LaneChangeBehavior(
			laneSectionToSwitch=newLaneSec,
			target_speed=globalParameters.EGO_SPEED)
		do FollowLaneBehavior(target_speed=globalParameters.EGO_SPEED) 

#################################
# Adversarial Behavior          #
#################################

param ADV_SPEED = Range(2, 4)

behavior Adversary1Behavior():
	do FollowLaneBehavior(target_speed=globalParameters.ADV_SPEED)

behavior Adversary2Behavior():
	rightLaneSec = self.laneSection.laneToRight
	do LaneChangeBehavior(
		laneSectionToSwitch=rightLaneSec,
		target_speed=globalParameters.ADV_SPEED)
	do FollowLaneBehavior(target_speed=globalParameters.ADV_SPEED)

behavior Adversary3Behavior():
	do FollowLaneBehavior(target_speed=globalParameters.ADV_SPEED)

#################################
# Spatial Relation              #
#################################
initLane = Uniform(*filter(lambda lane:
	all([sec._laneToRight is not None for sec in lane.sections]),
	network.lanes))
egoSpawnPt = new OrientedPoint in initLane.centerline
egoLaneSecToSwitch = initLane.sectionAt(egoSpawnPt).laneToRight

#################################
# Ego object                    #
#################################
ego = new Car at egoSpawnPt,
	with blueprint MODEL,
	with behavior EgoBehavior()

#################################
# Adversarial object            #
#################################
param ADV1_DIST = Range(20, 25)
param ADV2_DIST = globalParameters.ADV1_DIST + Range(15, 20)
param ADV3_DIST = globalParameters.ADV2_DIST + Range(15, 20)
adversary_1 = new Car following roadDirection for globalParameters.ADV1_DIST,
	with blueprint MODEL,
	with behavior Adversary1Behavior()

adversary_2 = new Car following roadDirection for globalParameters.ADV2_DIST,
	with blueprint MODEL,
	with behavior Adversary2Behavior()

adversary_3 = new Car following roadDirection for globalParameters.ADV3_DIST,
	with blueprint MODEL,
	with behavior Adversary3Behavior()

#################################
# Requirements and Restrictions #
#################################
INIT_DIST = 50
TERM_DIST = globalParameters.ADV3_DIST + 15

require (distance to intersection) > INIT_DIST
require (distance from adversary_1 to intersection) > INIT_DIST
require (distance from adversary_2 to intersection) > INIT_DIST
require (distance from adversary_3 to intersection) > INIT_DIST
terminate when (distance to adversary_3) > TERM_DIST