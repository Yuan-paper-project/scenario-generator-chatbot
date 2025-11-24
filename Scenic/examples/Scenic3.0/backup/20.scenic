#################################
# DESCRIPTION                   #
#################################

description = "Ego vehicle encounters pedestrian emerging from the obstacle and crossing the road. Ego must perform an emergency brake."


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
EGO_BRAKE = 1.0

PED_MIN_SPEED = 1.0
PED_THRESHOLD = 20

INIT_DIST = 80
SAFE_DIST = 10
TERM_DIST = 50

#################################
# AGENT BEHAVIORS               #
#################################

behavior EgoBehavior():
    try:
        do FollowLaneBehavior(target_speed=globalParameters.EGO_SPEED)
    interrupt when withinDistanceToObjsInLane(self, SAFE_DIST):
        take SetBrakeAction(EGO_BRAKE)

behavior PedBehavior():
    do CrossingBehavior(ego, PED_MIN_SPEED, PED_THRESHOLD)

#################################
# SPATIAL RELATIONS             #
#################################

lane = Uniform(*network.lanes)

#################################
# SCENARIO SPECIFICATION        #
#################################

SpawnPt = new OrientedPoint on lane.centerline
ObsSpawnPt = new OrientedPoint following roadDirection from SpawnPt for -3

pedestrian = new Pedestrian right of SpawnPt by 3,
    facing 90 deg relative to SpawnPt.heading,
    with regionContainedIn None,
    with behavior PedBehavior()

obstacle = new VendingMachine right of ObsSpawnPt by 3,
    facing -90 deg relative to ObsSpawnPt.heading,
    with regionContainedIn None

ego = new Car following roadDirection from SpawnPt for Range(-30, -20),
    with blueprint MODEL,
    with behavior EgoBehavior()

require (distance to intersection) > INIT_DIST
require (ego.laneSection._slowerLane is None)
terminate when (distance to SpawnPt) > TERM_DIST