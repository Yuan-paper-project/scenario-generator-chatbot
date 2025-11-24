#################################
# Description                   #
#################################

description = "Adversary vehicle performs a lane change to bypass the slow ego vehicle and another vehicle in front of it before returning to its original lane."

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

param EGO_SPEED = Range(2, 4)

behavior EgoBehavior():
	do FollowLaneBehavior(target_speed=globalParameters.EGO_SPEED)

#################################
# Adversarial Behavior
#################################

param ADV_SPEED = Range(7, 10)

BYPASS_DIST = [10, 5]

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
				target_speed=globalParameters.ADV_SPEED)
		do FollowLaneBehavior(target_speed=globalParameters.ADV_SPEED) 

#################################
# Spatial Relation
#################################

initLane = Uniform(*network.lanes)

egoSpawnPt = new OrientedPoint in initLane.centerline
otherSpawnPt = new OrientedPoint following roadDirection from egoSpawnPt for 40

#################################
# Ego object
#################################

ego = new Car at egoSpawnPt,
	with blueprint MODEL,
	with behavior EgoBehavior()

other = new Car at otherSpawnPt,
	with blueprint MODEL,
	with behavior EgoBehavior()

#################################
# Adversarial object            #
#################################

param ADV_DIST = Range(-25, -10)

adversary = new Car following roadDirection for globalParameters.ADV_DIST,
	with blueprint MODEL,
	with behavior AdversaryBehavior()

#################################
# Requirements and Restrictions #
#################################

INIT_DIST = 50
TERM_DIST = 100

require (distance to intersection) > INIT_DIST
require (distance from adversary to intersection) > INIT_DIST

require always (ego.laneSection._fasterLane is not None)
require always (other.laneSection._fasterLane is not None)

terminate when (distance to egoSpawnPt) > TERM_DIST