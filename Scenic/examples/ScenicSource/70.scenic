#################################
# Description                   #
#################################

description = "Ego vehicle switches to the faster lane and then after some time comes back to the original (slower) lane."

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
SWITCH_TIME = [5,5]

behavior EgoBehavior():
	do FollowLaneBehavior(target_speed=globalParameters.EGO_SPEED) for SWITCH_TIME[0] seconds
	do LaneChangeBehavior(laneSectionToSwitch=self.laneSection.fasterLane,target_speed=globalParameters.EGO_SPEED) 
	do FollowLaneBehavior(target_speed=globalParameters.EGO_SPEED) for SWITCH_TIME[1] seconds
	do LaneChangeBehavior(laneSectionToSwitch=self.laneSection.slowerLane,target_speed=globalParameters.EGO_SPEED)
	do FollowLaneBehavior(target_speed=globalParameters.EGO_SPEED) 

#################################
# Adversarial Behavior          #
#################################


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


#################################
# Requirements and Restrictions #
#################################

INIT_DIST = 50
TERM_DIST = 100
require (distance to intersection) > INIT_DIST
require always (ego.laneSection._fasterLane is not None)
terminate when (distance to egoSpawnPt) > TERM_DIST