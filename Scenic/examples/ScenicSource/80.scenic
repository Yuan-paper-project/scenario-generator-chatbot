#################################
# Description                   #
#################################

description = "Ego vehicle makes a left turn at an intersection while a pedestrian crosses the crosswalk on the right side."

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

param EGO_SPEED = Range(9, 10)

behavior EgoBehavior(trajectory):
    do FollowTrajectoryBehavior(target_speed=globalParameters.EGO_SPEED, trajectory=trajectory)

#################################
# Adversarial Behavior          #
#################################

PED_MIN_SPEED = 1.0
PED_THRESHOLD = 20
behavior PedestrianBehavior():
    do CrossingBehavior(ego, PED_MIN_SPEED, PED_THRESHOLD)

#################################
# Spatial Relation              #
#################################

intersection = Uniform(*filter(lambda i: i.is4Way or i.is3Way, network.intersections))
egoManeuver = Uniform(*filter(lambda m: m.type is ManeuverType.LEFT_TURN, intersection.maneuvers))
egoInitLane = egoManeuver.startLane
egoTrajectory = [egoInitLane, egoManeuver.connectingLane, egoManeuver.endLane]
egoSpawnPt = new OrientedPoint in egoInitLane.centerline
tempSpawnPt = egoInitLane.centerline[-1]

#################################
# Ego object                    #
#################################

ego = new Car at egoSpawnPt,
    with blueprint MODEL,
    with behavior EgoBehavior(egoTrajectory)

#################################
# Adversarial object            #
#################################

ped = new Pedestrian right of tempSpawnPt by 5,
    facing ego.heading,
    with regionContainedIn None,
    with behavior PedestrianBehavior()

#################################
# Requirements and Restrictions #
#################################

EGO_INIT_DIST = [20, 25]
TERM_DIST = 100
require EGO_INIT_DIST[0] <= (distance to intersection) <= EGO_INIT_DIST[1]
terminate when (distance to egoSpawnPt) > TERM_DIST