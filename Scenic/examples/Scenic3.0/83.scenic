#################################
# DESCRIPTION                   #
#################################

description = "Ego vehicle makes a left turn at an intersection and must stop to avoid collision when a crowd of pedestrians cross the crosswalk."

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

EGO_INIT_DIST = [20, 25]
param EGO_SPEED = Range(7, 10)
param EGO_BRAKE = Range(0.8, 1.0)

PED_MIN_SPEED = 1.0
PED_THRESHOLD = 20

SAFE_DIST = 20
TERM_DIST = 100

#################################
# AGENT BEHAVIORS               #
#################################

behavior EgoBehavior(trajectory):
    try:
        do FollowTrajectoryBehavior(target_speed=globalParameters.EGO_SPEED, trajectory=trajectory)
    interrupt when withinDistanceToAnyObjs(self, SAFE_DIST) and (ped in network.drivableRegion):
        take SetBrakeAction(globalParameters.EGO_BRAKE)

behavior PedestrianBehavior():
    do CrossingBehavior(ego, PED_MIN_SPEED, PED_THRESHOLD)

#################################
# SPATIAL RELATIONS             #
#################################

intersection = Uniform(*filter(lambda i: i.is4Way or i.is3Way, network.intersections))

egoManeuver = Uniform(*filter(lambda m: m.type is ManeuverType.LEFT_TURN, intersection.maneuvers))
egoInitLane = egoManeuver.startLane
egoTrajectory = [egoInitLane, egoManeuver.connectingLane, egoManeuver.endLane]
egoSpawnPt = new OrientedPoint in egoInitLane.centerline

tempManeuver = Uniform(*filter(lambda m: m.type is ManeuverType.RIGHT_TURN, egoManeuver.reverseManeuvers))
tempInitLane = tempManeuver.startLane
tempSpawnPt = tempInitLane.centerline[-1]

#################################
# SCENARIO SPECIFICATION        #
#################################

ego = new Car at egoSpawnPt,
    with blueprint MODEL,
    with behavior EgoBehavior(egoTrajectory)

ped = new Pedestrian right of tempSpawnPt by 3,
    facing ego.heading,
    with regionContainedIn None,
    with behavior PedestrianBehavior()

require EGO_INIT_DIST[0] <= (distance to intersection) <= EGO_INIT_DIST[1]
terminate when (distance to egoSpawnPt) > TERM_DIST
