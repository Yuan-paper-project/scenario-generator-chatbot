#################################
# Description                   #
#################################
description = "Ego vehicle performs a lane change to a faster lane."

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
TIME = 5

behavior EgoBehavior():

	do FollowLaneBehavior(target_speed=globalParameters.EGO_SPEED) for TIME seconds
	do LaneChangeBehavior(laneSectionToSwitch=self.laneSection.fasterLane, target_speed=globalParameters.EGO_SPEED)
	do FollowLaneBehavior(target_speed=globalParameters.EGO_SPEED)

ego = new Car at egoSpawnPt,
	with blueprint MODEL,
	with behavior EgoBehavior()

#################################
# Adversarial                   #
#################################

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
require always (ego.laneSection._fasterLane is not None)
terminate when (distance to egoSpawnPt) > TERM_DIST