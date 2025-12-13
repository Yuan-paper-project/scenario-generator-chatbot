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
egoDir = egoSpawnPt.heading
advDir = advSpawnPt.heading

param EGO_SPEED = Range(7, 10)
param OPT_ADV_SPEED = Range(1, 5)
param OPT_ADV_DISTANCE = Range(40, 70)
OPT_ADV_STOP_DISTANCE = 1
behavior WaitBehavior():
    while True:
        wait
behavior AdvBehavior(actor_reference, adv_speed, adv_distance, stop_reference, stop_distance):
    do WaitBehavior() until (distance from self to actor_reference) <= adv_distance
    do FollowLaneBehavior(adv_speed) until distance from self to stop_reference <= stop_distance
    take SetThrottleAction(0)
    take SetBrakeAction(1)
behavior EgoBehavior(trajectory):
    do FollowTrajectoryBehavior(target_speed=globalParameters.EGO_SPEED, trajectory=trajectory)
ego = new Car at egoSpawnPt,
    with blueprint EGO_MODEL,
    with behavior EgoBehavior(egoTrajectory)
AdvAgent = new Car at advSpawnPt,
    with heading advSpawnPt.heading,
    with regionContainedIn None,
    with behavior AdvBehavior(ego, globalParameters.OPT_ADV_SPEED,globalParameters.OPT_ADV_DISTANCE, egoTrajectoryLine, OPT_ADV_STOP_DISTANCE)

CONST_RIGHT_DEG = - 90 deg
CONST_TOL_DEG = 20 deg
CONST_MIN_RIGHT_DEG = CONST_RIGHT_DEG - CONST_TOL_DEG
CONST_MAX_RIGHT_DEG = CONST_RIGHT_DEG + CONST_TOL_DEG
monitor TrafficLights():
    freezeTrafficLights()
    while True:
        if withinDistanceToTrafficLight(ego, 100):
            setClosestTrafficLightStatus(ego, "red")
        if withinDistanceToTrafficLight(AdvAgent, 100):
            setClosestTrafficLightStatus(AdvAgent, "green")
        wait
require CONST_MIN_RIGHT_DEG < (egoDir - advDir) < CONST_MAX_RIGHT_DEG
require monitor TrafficLights()
require 30 <= (distance from egoSpawnPt to intersection) <= 40
require 5 <= (distance from advSpawnPt to intersection) <= 10