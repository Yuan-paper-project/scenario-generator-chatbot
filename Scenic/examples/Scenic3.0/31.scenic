#################################
# DESCRIPTION                   #
#################################

description = "There are three vehicles in the scene: ego, adversary, and a lead vehicle. Ego vehicle performs a lane change to bypass the adversary vehicle. In responce to that adversary, ego moves to the slower lane. The lead vehicle is in fron and continues following the lane."

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

param EGO_SPEED = Range(7, 10)
param EGO_BRAKE = Range(0.7, 1.0)

param ADV_DIST = Range(10, 15)
param ADV_SPEED = Range(2, 4)
ADV_BUFFER_TIME = 5

LEAD_DIST = globalParameters.ADV_DIST + 10
LEAD_SPEED = globalParameters.EGO_SPEED 

BYPASS_DIST = [15, 10]
SAFE_DIST = 15
INIT_DIST = 50
TERM_DIST = 100

#################################
# AGENT BEHAVIORS               #
#################################

behavior EgoBehavior():
	try:
		do FollowLaneBehavior(target_speed=globalParameters.EGO_SPEED)
	interrupt when (distance to adversary) < BYPASS_DIST[0]:
		fasterLaneSec = self.laneSection.fasterLane
		do LaneChangeBehavior(
				laneSectionToSwitch=fasterLaneSec,
				target_speed=globalParameters.EGO_SPEED)
		do FollowLaneBehavior(
				target_speed=globalParameters.EGO_SPEED,
				laneToFollow=fasterLaneSec.lane) \
			until (distance to adversary) > BYPASS_DIST[1]

behavior AdversaryBehavior():
	do FollowLaneBehavior(target_speed=globalParameters.ADV_SPEED) \
		until self.lane is not ego.lane
	slowerLane = self.laneSection.slowerLane
	do LaneChangeBehavior(
		laneSectionToSwitch=slowerLane,
		target_speed=globalParameters.ADV_SPEED)

behavior LeadBehavior():
	fasterLaneSec = self.laneSection.fasterLane
	do LaneChangeBehavior(
			laneSectionToSwitch=fasterLaneSec,
			target_speed=LEAD_SPEED)
	do FollowLaneBehavior(target_speed=LEAD_SPEED)

#################################
# SPATIAL RELATIONS             #
#################################

initLane = Uniform(*network.lanes)
egoSpawnPt = new OrientedPoint in initLane.centerline

#################################
# SCENARIO SPECIFICATION        #
#################################

ego = new Car at egoSpawnPt,
	with blueprint MODEL,
	with behavior EgoBehavior()

adversary = new Car following roadDirection for globalParameters.ADV_DIST,
	with blueprint MODEL,
	with behavior AdversaryBehavior()

lead = new Car following roadDirection for LEAD_DIST,
	with blueprint MODEL,
	with behavior LeadBehavior()

require (distance to intersection) > INIT_DIST
require (distance from adversary to intersection) > INIT_DIST
require (distance from lead to intersection) > INIT_DIST
require (adversary.laneSection._fasterLane is not None)
require (adversary.laneSection._slowerLane is not None)
terminate when (distance to egoSpawnPt) > TERM_DIST
