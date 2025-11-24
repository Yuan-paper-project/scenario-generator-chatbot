#################################
# DESCRIPTION                   #
#################################

description = "Ego vehicle performs a lane changing to evade a leading vehicle, which is moving too slowly."

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


#CONSTANTS
param EGO_SPEED = Range(9, 12)
param LEAD_SPEED = Range(3, 6)

LEAD_INIT_DIST = 10

BYPASS_DIST = 10
INIT_DIST = 10
TERM_DIST = 50

#################################
# AGENT BEHAVIORS               #
#################################

behavior EgoBehavior():
    laneChangeCompleted = False
    try: 
        do FollowLaneBehavior(globalParameters.EGO_SPEED)
    interrupt when withinDistanceToAnyObjs(self, BYPASS_DIST) and not laneChangeCompleted:
        rightLaneSec = self.laneSection._laneToRight
        do LaneChangeBehavior(laneSectionToSwitch=rightLaneSec, target_speed=globalParameters.EGO_SPEED)
        laneChangeCompleted = True

#OTHER BEHAVIOR
behavior LeadBehavior():
    do FollowLaneBehavior(globalParameters.LEAD_SPEED)

#################################
# SPATIAL RELATIONS             #
#################################

initLane = Uniform(*filter(lambda lane:all([sec._laneToRight is not None for sec in lane.sections]),network.lanes))
egoSpawnPt = new OrientedPoint on initLane.centerline

#################################
# SCENARIO SPECIFICATION        #
#################################

ego = new Car at egoSpawnPt,
    with blueprint MODEL,
    with behavior EgoBehavior()

lead = new Car following roadDirection from ego for LEAD_INIT_DIST,
    with behavior LeadBehavior()

require (distance from ego to intersection) > INIT_DIST
require (distance from lead to intersection) > INIT_DIST
terminate when (distance to egoSpawnPt) > TERM_DIST
