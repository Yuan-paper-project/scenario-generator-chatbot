#################################
# DESCRIPTION                   #
#################################

description = "Ego vehicle performs a lane change to a faster lane."

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
TIME = 5
TERM_DIST = 100

#################################
# AGENT BEHAVIORS               #
#################################

behavior EgoBehavior():

	do FollowLaneBehavior(target_speed=globalParameters.EGO_SPEED) for TIME seconds
	do LaneChangeBehavior(laneSectionToSwitch=self.laneSection.fasterLane, target_speed=globalParameters.EGO_SPEED)
	do FollowLaneBehavior(target_speed=globalParameters.EGO_SPEED) 

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

require (distance to intersection) > INIT_DIST
require always (ego.laneSection._fasterLane is not None)
terminate when (distance to egoSpawnPt) > TERM_DIST