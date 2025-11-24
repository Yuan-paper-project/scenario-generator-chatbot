#################################
# Description                   #
#################################

description = "Ego vehicle encounters pedestrian emerging from the obstacle and crossing the road. Ego must perform an emergency brake."

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
EGO_BRAKE = 1.0
SAFE_DIST = 10

behavior EgoBehavior():
    try:
        do FollowLaneBehavior(target_speed=globalParameters.EGO_SPEED)
    interrupt when withinDistanceToObjsInLane(self, SAFE_DIST):
        take SetBrakeAction(EGO_BRAKE)

#################################
# Adversarial Behavior          #
#################################

PED_MIN_SPEED = 1.0
PED_THRESHOLD = 20

behavior PedBehavior():
    do CrossingBehavior(ego, PED_MIN_SPEED, PED_THRESHOLD)

#################################
# Spatial Relation              #
#################################

lane = Uniform(*network.lanes)
SpawnPt = new OrientedPoint on lane.centerline
ObsSpawnPt = new OrientedPoint following roadDirection from SpawnPt for -3

#################################
# Ego object                    #
#################################


ego = new Car following roadDirection from SpawnPt for Range(-30, -20),
    with blueprint MODEL,
    with behavior EgoBehavior()

#################################
# Adversarial object            #
#################################

pedestrian = new Pedestrian right of SpawnPt by 3,
    facing 90 deg relative to SpawnPt.heading,
    with regionContainedIn None,
    with behavior PedBehavior()

obstacle = new VendingMachine right of ObsSpawnPt by 3,
    facing -90 deg relative to ObsSpawnPt.heading,
    with regionContainedIn None

#################################
# Requirements and Restrictions #
#################################

INIT_DIST = 80
TERM_DIST = 50

require (distance to intersection) > INIT_DIST
require (ego.laneSection._slowerLane is None)
terminate when (distance to SpawnPt) > TERM_DIST