#################################
# Description                   #
#################################
description = "There are three vehicles in the scene: ego, adversary, and a lead vehicle. Ego and lead vehicle moves to the faster lane while adversary remains in its current lane."

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
param EGO_SPEED = Range(7, 10)

behavior FasterBehavior():
	fasterLaneSec = self.laneSection.fasterLane
	do LaneChangeBehavior(
		laneSectionToSwitch=fasterLaneSec,
		target_speed=globalParameters.EGO_SPEED)
	do FollowLaneBehavior(target_speed=globalParameters.EGO_SPEED)


ego = new Car at egoSpawnPt,
	with blueprint MODEL,
	with behavior FasterBehavior()

#################################
# Adversarial                   #
#################################
param ADV_SPEED = Range(7, 10)

behavior AdversaryBehavior():
	do FollowLaneBehavior(target_speed=globalParameters.ADV_SPEED)

param ADV_DIST = Range(10, 15)

adversary = new Car following roadDirection for globalParameters.ADV_DIST,
	with blueprint MODEL,
	with behavior AdversaryBehavior()

#################################
# Adversarial                   #
#################################
param EGO_SPEED = Range(7, 10)

behavior FasterBehavior():
	fasterLaneSec = self.laneSection.fasterLane
	do LaneChangeBehavior(
		laneSectionToSwitch=fasterLaneSec,
		target_speed=globalParameters.EGO_SPEED)
	do FollowLaneBehavior(target_speed=globalParameters.EGO_SPEED)

param ADV_DIST = Range(10, 15)
LEAD_DIST = globalParameters.ADV_DIST + 15

lead = new Car following roadDirection for LEAD_DIST,
	with blueprint MODEL,
	with behavior FasterBehavior()

#################################
# Spatial Relation              #
#################################
initLane = Uniform(*network.lanes)
egoSpawnPt = new OrientedPoint in initLane.centerline

#################################
# Requirements and Restrictions #
#################################
INIT_DIST = 50
TERM_DIST = 100

require (distance to intersection) > INIT_DIST
require (distance from adversary to intersection) > INIT_DIST
require (distance from lead to intersection) > INIT_DIST
require always (adversary.laneSection._fasterLane is not None)
terminate when (distance to egoSpawnPt) > TERM_DIST