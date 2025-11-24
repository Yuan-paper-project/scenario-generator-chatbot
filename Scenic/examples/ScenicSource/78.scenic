#################################
# Description                   #
#################################
description = "Ego vehicle encounters a chain of debris in its lane but continues to drive in the same lane."

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
param EGO_SPEED = Range(10, 20)
behavior EgoBehavior(speed=10):
    do FollowLaneBehavior(target_speed=globalParameters.EGO_SPEED)

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
debris1 = new Debris following roadDirection for Range(10, 20)
debris2 = new Debris following roadDirection from debris1 for Range(5, 10)
debris3 = new Debris following roadDirection from debris2 for Range(5, 10)

#################################
# Requirements and Restrictions #
#################################
INIT_DIST = 50
TERM_DIST = 50
require (distance to intersection) > INIT_DIST
terminate when (distance from debris3 to ego) > 10 and (distance to egoSpawnPt) > TERM_DIST