description = "Vehicle is going straight in an urban area, with a posted speed limit of 35 mph; vehicle then runs a red light, crossing an intersection and colliding with another vehicle crossing the intersection from a lateral direction"
Town = 'Town05'
param map = localPath(f'../../assets/maps/CARLA/{Town}.xodr')
param carla_map = Town
model scenic.simulators.carla.model
EGO_MODEL = "vehicle.lincoln.mkz_2017"


intersection = Uniform(*filter(lambda i: i.is4Way and i.isSignalized, network.intersections))
egoManeuver = Uniform(*filter(lambda m: m.type is ManeuverType.STRAIGHT, intersection.maneuvers))
egoInitLane = egoManeuver.startLane
egoTrajectory = [egoInitLane, egoManeuver.connectingLane, egoManeuver.endLane]
egoTrajectoryLine = egoInitLane.centerline + egoManeuver.connectingLane.centerline + egoManeuver.endLane.centerline
egoSpawnPt = new OrientedPoint in egoInitLane.centerline
advManeuver = Uniform(*filter(lambda m: m.type is ManeuverType.STRAIGHT, egoManeuver.conflictingManeuvers))
advInitLane = advManeuver.startLane
advTrajectory = [advInitLane, advManeuver.connectingLane, advManeuver.endLane]
advSpawnPt = new OrientedPoint in advInitLane.centerline

param EGO_SPEED = Range(13, 15)
behavior EgoBehavior(trajectory):
    do FollowTrajectoryBehavior(target_speed=globalParameters.EGO_SPEED, trajectory=trajectory)
ego = new Car at egoSpawnPt,
    with blueprint EGO_MODEL,
    with behavior EgoBehavior(egoTrajectory)
param OPT_ADV_SPEED = Range(7, 10)
param OPT_ADV_DISTANCE = Range(40, 70)
OPT_ADV_STOP_DISTANCE = 1
behavior WaitBehavior():
    while True:
        wait
behavior AdvBehavior(adv_speed): # Simplified behavior for AdvAgent to proceed
    do FollowLaneBehavior(adv_speed)
AdvAgent = new Car at advSpawnPt,
    with heading advSpawnPt.heading,
    with regionContainedIn None,
    with behavior AdvBehavior(globalParameters.OPT_ADV_SPEED) # Simplified call to AdvBehavior

egoDir = egoSpawnPt.heading
advDir = advSpawnPt.heading
CONST_RIGHT_DEG = - 90 deg
CONST_TOL_DEG = 20 deg
CONST_MIN_RIGHT_DEG = CONST_RIGHT_DEG - CONST_TOL_DEG
CONST_MAX_RIGHT_DEG = CONST_RIGHT_DEG + CONST_TOL_DEG
monitor TrafficLights():
    freezeTrafficLights()
    while True:
        if withinDistanceToTrafficLight(ego, 100):
            setClosestTrafficLightStatus(ego, "red") # Ego runs a red light
        if withinDistanceToTrafficLight(AdvAgent, 100):
            setClosestTrafficLightStatus(AdvAgent, "green") # AdvAgent has a green light
        wait
require CONST_MIN_RIGHT_DEG < (egoDir - advDir) < CONST_MAX_RIGHT_DEG
require monitor TrafficLights()
require 30 <= (distance from egoSpawnPt to intersection) <= 40
require 5 <= (distance from advSpawnPt to intersection) <= 10