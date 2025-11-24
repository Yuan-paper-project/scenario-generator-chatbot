#################################
# DESCRIPTION                   #
#################################

description = "Ego vehicle encounters a chain of debris in its lane but continues to drive in the same lane."

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

param EGO_SPEED = Range(10, 20)

INIT_DIST = 50
TERM_DIST = 50

#################################
# AGENT BEHAVIORS               #
#################################

behavior EgoBehavior(speed=10):
    do FollowLaneBehavior(target_speed=globalParameters.EGO_SPEED)

#################################
# SPATIAL RELATIONS             #
#################################

lane = Uniform(*network.lanes)
egoSpawnPt = new OrientedPoint on lane.centerline

#################################
# SCENARIO SPECIFICATION        #
#################################

ego = new Car at egoSpawnPt,
    with blueprint MODEL,
    with behavior EgoBehavior()

debris1 = new Debris following roadDirection for Range(10, 20)
debris2 = new Debris following roadDirection from debris1 for Range(5, 10)
debris3 = new Debris following roadDirection from debris2 for Range(5, 10)

require (distance to intersection) > INIT_DIST
terminate when (distance from debris3 to ego) > 10 and (distance to egoSpawnPt) > TERM_DIST