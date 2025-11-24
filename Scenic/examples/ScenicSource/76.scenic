#################################
# Description                   #
#################################

description = "Ego vehicle encounters a chain of debris in its lane. it moves the faster lane to bypass the debris and then returns to its original lane."

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
BYPASS_DIST = [10, 20]

behavior EgoBehavior(speed=10):
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
			until (distance to adversary) > BYPASS_DIST[1]
		slowerLaneSec = self.laneSection.slowerLane
		do LaneChangeBehavior(
				laneSectionToSwitch=slowerLaneSec,
				target_speed=globalParameters.EGO_SPEED)

#################################
# Adversarial Behavior          #
#################################


#################################
# Spatial Relation              #
#################################

lane = Uniform(*network.lanes)
egoSpawnPt = new OrientedPoint on lane.centerline

#################################
# Ego object                    #
#################################


ego = new Car at egoSpawnPt,
    with blueprint MODEL,
    with behavior EgoBehavior()

#################################
# Adversarial object            #
#################################

debris1 = new Debris following roadDirection for Range(20, 25)
debris2 = new Debris following roadDirection from debris1 for Range(5, 10)
debris3 = new Debris following roadDirection from debris2 for Range(5, 10)

#################################
# Requirements and Restrictions #
#################################

INIT_DIST = 50
TERM_DIST = 50

require (distance to intersection) > INIT_DIST
terminate when (distance from debris3 to ego) > 20 and (distance to egoSpawnPt) > TERM_DIST
require always (ego.laneSection._fasterLane is not None)