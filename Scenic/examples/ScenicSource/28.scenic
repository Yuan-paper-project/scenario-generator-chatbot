#################################
# Description                   #
#################################

description = "Adversary vehicle trys to overtake the ego vehicle with ego vehicle responding by stopping and resumming travel after some time."

#################################
# Header                        #
#################################

param map = localPath('../../assets/maps/CARLA/Town05.xodr')
param carla_map = 'Town05'
model scenic.simulators.carla.model

MODEL = 'vehicle.mini.cooper_s_2021'
BYPASS_DIST = [15, 10]

#################################
# Ego Behavior                  #
#################################

param EGO_SPEED = Range(2, 4)
param EGO_BRAKE = Range(0.5, 1.0)

behavior EgoBehaviour():
	try:
		do FollowLaneBehavior(target_speed=globalParameters.EGO_SPEED)
	interrupt when withinDistanceToAnyObjs(self, BYPASS_DIST[0]):
		take SetBrakeAction(globalParameters.EGO_BRAKE)

#################################
# Adversarial Behavior          #
#################################

param ADV_SPEED = Range(7, 10)

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
# Spatial Relation              #
#################################

initLane = Uniform(*network.lanes)
egoSpawnPt = new OrientedPoint in initLane.centerline

#################################
# Ego object                    #
#################################

ego = new Car at egoSpawnPt,
	with blueprint MODEL,
	with behavior EgoBehaviour()

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

require always (ego.laneSection._slowerLane is not None)
terminate when (distance to egoSpawnPt) > TERM_DIST