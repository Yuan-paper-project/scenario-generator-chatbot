#################################
# Description                   #
#################################
description = "Adversary vehicle performs a bypass and when the adversary comes close to the ego vehicle it moves to tthe slower lane."

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
param EGO_SPEED = Range(2, 4)
BYPASS_DIST = [15, 10]

behavior EgoBehaviour():
	try:
		do FollowLaneBehavior(target_speed=globalParameters.EGO_SPEED)
	interrupt when withinDistanceToAnyObjs(self, BYPASS_DIST[1]):
		slowerLaneSec = self.laneSection.slowerLane
		do LaneChangeBehavior(
				laneSectionToSwitch=slowerLaneSec,
				target_speed=globalParameters.EGO_SPEED)
		do FollowLaneBehavior(target_speed=globalParameters.EGO_SPEED)

ego = new Car at egoSpawnPt,
	with blueprint MODEL,
	with behavior EgoBehaviour()

#################################
# Adversarial                   #
#################################
param ADV_SPEED = Range(5, 7)
param ADV_DIST = Range(-25, -10)
BYPASS_DIST = [15, 10]
param EGO_SPEED = Range(2, 4) # Duplicated: used by AdversaryBehavior

behavior AdversaryBehavior():
	try:
		do FollowLaneBehavior(target_speed=globalParameters.ADV_SPEED)
	interrupt when withinDistanceToAnyObjs(self, BYPASS_DIST[0]):
		fasterLaneSec = self.laneSection.fasterLane
		do LaneChangeBehavior(
				laneSectionToSwitch=fasterLaneSec,
				target_speed=globalParameters.ADV_SPEED)
		do FollowLaneBehavior(
				target_speed=globalParameters.ADV_SPEED,
				laneToFollow=fasterLaneSec.lane) \
			until (distance to adversary) > BYPASS_DIST[1]
		slowerLaneSec = self.laneSection.slowerLane
		do LaneChangeBehavior(
				laneSectionToSwitch=slowerLaneSec,
				target_speed=globalParameters.EGO_SPEED)
		do FollowLaneBehavior(target_speed=globalParameters.EGO_SPEED)

adversary = new Car following roadDirection for globalParameters.ADV_DIST,
	with blueprint MODEL,
	with behavior AdversaryBehavior()

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

require always (ego.laneSection._fasterLane is not None)
terminate when (distance to egoSpawnPt) > TERM_DIST