#################################
# Description                   #
#################################

description = "Ego vehicle performs a lane change to bypass a slow adversary vehicle before returning to its original lane."

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

BYPASS_DIST = [15, 5]

behavior EgoBehavior():
	try:
		do FollowLaneBehavior(target_speed=globalParameters.EGO_SPEED)
	interrupt when withinDistanceToAnyObjs(self, BYPASS_DIST[0]):
		fasterLaneSec = self.laneSection.fasterLane
		do LaneChangeBehavior(
				laneSectionToSwitch=fasterLaneSec,
				target_speed=globalParameters.EGO_SPEED)
		do FollowLaneBehavior(
				target_speed=globalParameters.EGO_SPEED,
				laneToFollow=fasterLaneSec.lane) \
			until (distance to adv) > BYPASS_DIST[1]
		slowerLaneSec = self.laneSection.slowerLane
		do LaneChangeBehavior(
				laneSectionToSwitch=slowerLaneSec,
				target_speed=globalParameters.EGO_SPEED)
		do FollowLaneBehavior(target_speed=globalParameters.EGO_SPEED) 

#################################
# Adversarial Behavior          #
#################################

param ADV_SPEED = Range(2, 4)

behavior AdvBehavior():
	do FollowLaneBehavior(target_speed=globalParameters.ADV_SPEED)

#################################
# Spatial Relation              #
#################################

initLane = Uniform(*network.lanes)
egoSpawnPt = new OrientedPoint in initLane.centerline

#################################
# Ego object                    #
#################################

ego = new Car at egoSpawnPt,
	with blueprint MODEL,
	with behavior EgoBehavior()

#################################
# Adversarial object            #
#################################

param ADV_DIST = Range(10, 25)

adv = new Car following roadDirection for globalParameters.ADV_DIST,
	with blueprint MODEL,
	with behavior AdvBehavior()

#################################
# Requirements and Restrictions #
#################################

INIT_DIST = 50
TERM_DIST = 100

require (distance to intersection) > INIT_DIST
require (distance from adv to intersection) > INIT_DIST
require always (adv.laneSection._fasterLane is not None)
terminate when (distance to egoSpawnPt) > TERM_DIST