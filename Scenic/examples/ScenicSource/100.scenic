#################################
# Description                   #
#################################

description = "Ego vehicle performs a lane change to bypass a slow adversary vehicle but cannot return to its original lane because the adversary accelerates. Ego vehicle stops to avoid collision with leading vehicle in new lane that suddenly decided to stop."

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
param EGO_BRAKE = Range(0.7, 1.0)

BYPASS_DIST = [15, 10]
SAFE_DIST = 15

behavior EgoBehavior():
	try:
		do FollowLaneBehavior(target_speed=globalParameters.EGO_SPEED)
	interrupt when (distance to adversary) < BYPASS_DIST[0]:
		fasterLaneSec = self.laneSection.fasterLane
		do LaneChangeBehavior(
				laneSectionToSwitch=fasterLaneSec,
				target_speed=globalParameters.EGO_SPEED)
		try:
			do FollowLaneBehavior(
					target_speed=globalParameters.EGO_SPEED,
					laneToFollow=fasterLaneSec.lane) \
				until (distance to adversary) > BYPASS_DIST[1]
		interrupt when (distance to lead) < SAFE_DIST:
			take SetBrakeAction(globalParameters.EGO_BRAKE)


ego = new Car at egoSpawnPt,
	with blueprint MODEL,
	with behavior EgoBehavior()

#################################
# Adversarial                   #
#################################

param ADV_INIT_SPEED = Range(2, 4)
param ADV_END_SPEED = 2 * Range(7, 10)
ADV_BUFFER_TIME = 5

behavior AdversaryBehavior():
	do FollowLaneBehavior(target_speed=globalParameters.ADV_INIT_SPEED) \
		until self.lane is not ego.lane
	do FollowLaneBehavior(target_speed=globalParameters.ADV_END_SPEED)

param ADV_DIST = Range(10, 15)

adversary = new Car following roadDirection for globalParameters.ADV_DIST,
	with blueprint MODEL,
	with behavior AdversaryBehavior()

#################################
# Adversarial                   #
#################################

param EGO_SPEED = Range(7, 10)
param EGO_BRAKE = Range(0.7, 1.0)

LEAD_SPEED = globalParameters.EGO_SPEED - 4
LEAD_BRAKE = globalParameters.EGO_BRAKE

behavior LeadBehavior():
	fasterLaneSec = self.laneSection.fasterLane
	do LaneChangeBehavior(
			laneSectionToSwitch=fasterLaneSec,
			target_speed=LEAD_SPEED)
	take SetBrakeAction(LEAD_BRAKE)

param ADV_DIST = Range(10, 15)
LEAD_DIST = globalParameters.ADV_DIST + 10

lead = new Car following roadDirection for LEAD_DIST,
	with blueprint MODEL,
	with behavior LeadBehavior()

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