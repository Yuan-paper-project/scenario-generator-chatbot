#################################
# Description                   #
#################################

description = "Ego vehicle goes straight at an intersection and must yield when a chain of pedestrians crosses the crosswalk."

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
param EGO_BRAKE = Range(0.5, 1.0)
SAFE_DIST = 10

behavior EgoBehavior(trajectory):
	try:
		do FollowTrajectoryBehavior(target_speed=globalParameters.EGO_SPEED, trajectory=trajectory)
	interrupt when withinDistanceToAnyObjs(self, SAFE_DIST) and (ped in network.drivableRegion):
		take SetBrakeAction(globalParameters.EGO_BRAKE)

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

egoManeuver = Uniform(*filter(lambda m: m.type is ManeuverType.STRAIGHT, intersection.maneuvers))
egoInitLane = egoManeuver.startLane
egoTrajectory = [egoInitLane, egoManeuver.connectingLane, egoManeuver.endLane]
egoSpawnPt = new OrientedPoint in egoInitLane.centerline

tempManeuver = Uniform(*filter(lambda m: m.type is ManeuverType.STRAIGHT, egoManeuver.reverseManeuvers))
tempInitLane = tempManeuver.startLane
tempSpawnPt = tempInitLane.centerline[-1]

#################################
# Ego object                    #
#################################

ego = new Car at egoSpawnPt,
    with blueprint MODEL,
    with behavior EgoBehavior(egoTrajectory)

#################################
# Adversarial object            #
#################################

ped = new Pedestrian at tempSpawnPt,
    facing -90 deg relative to ego.heading,
    with regionContainedIn None,
    with behavior PedestrianBehavior()

ped2 = new Pedestrian behind tempSpawnPt by 2,
    facing -90 deg relative to ego.heading,
    with regionContainedIn None,
    with behavior PedestrianBehavior()

ped3 = new Pedestrian ahead of tempSpawnPt by 2,
    facing -90 deg relative to ego.heading,
    with regionContainedIn None,
    with behavior PedestrianBehavior()

#################################
# Requirements and Restrictions #
#################################

EGO_INIT_DIST = [20, 25]
TERM_DIST = 100

require EGO_INIT_DIST[0] <= (distance to intersection) <= EGO_INIT_DIST[1]
terminate when (distance to egoSpawnPt) > TERM_DIST