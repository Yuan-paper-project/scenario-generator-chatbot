#################################
# DESCRIPTION                   #
#################################

description = "Ego vehicle must go around an obstacle (stationary car) using the opposite lane, yielding to oncoming traffic."

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
param EGO_BRAKE = Range(0.5,1.0)
param ADV_SPEED = Range(7, 10)

ADV_INIT_DIST = [20, 25]
BYPASS_DIST = [10,15]

INIT_DIST = 80
TERM_DIST = 50

#################################
# AGENT BEHAVIORS               #
#################################

behavior EgoBehavior():
    try:
        do FollowLaneBehavior(globalParameters.EGO_SPEED)
    interrupt when (distance to obsctacle) < BYPASS_DIST[1]:
        leftLaneSec = self.laneSection.laneToLeft
        do LaneChangeBehavior(laneSectionToSwitch=leftLaneSec, is_oppositeTraffic=True, target_speed=globalParameters.EGO_SPEED)
        do FollowLaneBehavior(globalParameters.EGO_SPEED, is_oppositeTraffic=True) until (distance to obsctacle) > BYPASS_DIST[0]
    interrupt when (obsctacle can see self) and (distance to obsctacle) > BYPASS_DIST[0]:
        rightLaneSec = self.laneSection.laneToRight
        do LaneChangeBehavior(laneSectionToSwitch=rightLaneSec,
                            is_oppositeTraffic=False,
                            target_speed=globalParameters.EGO_SPEED)

behavior AdversaryBehavior():
    do FollowLaneBehavior(globalParameters.ADV_SPEED)


#################################
# SPATIAL RELATIONS             #
#################################

initLane = Uniform(*filter(lambda lane:
	all([sec._laneToLeft is not None and sec._laneToLeft.isForward is not sec.isForward for sec in lane.sections]),
	network.lanes))

egoSpawnPt = new OrientedPoint on initLane.centerline

#################################
# SCENARIO SPECIFICATION        #
#################################

ego = new Car at egoSpawnPt,
    with blueprint MODEL,
    with behavior EgoBehavior()

adv = new Car on initLane.centerline,
    with blueprint MODEL,
    with behavior AdversaryBehavior()

obsctacle = new Car following roadDirection from ego for ADV_INIT_DIST[1],
    with blueprint MODEL,
    with viewAngle 90 deg

require (distance from obsctacle to adv) < ADV_INIT_DIST[0]
require (distance to intersection) > INIT_DIST
terminate when (distance to egoSpawnPt) > TERM_DIST