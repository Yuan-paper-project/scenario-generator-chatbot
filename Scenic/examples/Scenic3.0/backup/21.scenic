#################################
# DESCRIPTION                   #
#################################

description = "Ego vehicle performs a lane change to overtake debris and then returns to its original lane."

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

BYPASS_DIST = [15, 10]
INIT_DIST = 50
TERM_DIST = 100

#################################
# AGENT BEHAVIORS               #
#################################

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
			until (distance to debris) > BYPASS_DIST[1]
		slowerLaneSec = self.laneSection.slowerLane
		do LaneChangeBehavior(
				laneSectionToSwitch=slowerLaneSec,
				target_speed=globalParameters.EGO_SPEED)
		do FollowLaneBehavior(target_speed=globalParameters.EGO_SPEED) 

#################################
# SPATIAL RELATIONS             #
#################################

initLane = Uniform(*network.lanes)
egoSpawnPt = new OrientedPoint in initLane.centerline
debrisSpawnPt = new OrientedPoint following roadDirection from egoSpawnPt for 30

#################################
# SCENARIO SPECIFICATION        #
#################################

ego = new Car at egoSpawnPt,
	with blueprint MODEL,
	with behavior EgoBehavior()

debris = new Debris right of debrisSpawnPt by 1,
    facing -90 deg relative to debrisSpawnPt.heading,
    with regionContainedIn None

require (distance to intersection) > INIT_DIST
require (distance from debris to intersection) > INIT_DIST
require always (debris.laneSection._fasterLane is not None)
terminate when (distance to egoSpawnPt) > TERM_DIST