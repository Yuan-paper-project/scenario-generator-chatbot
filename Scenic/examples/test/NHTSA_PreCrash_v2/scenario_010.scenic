description = "Ego vehicle turning left at a signaled intersection encounters a pedestrian in a crosswalk under clear daylight conditions."
param map = localPath('../../assets/maps/CARLA/Town05.xodr')
param carla_map = 'Town05'
model scenic.simulators.carla.model
MODEL = 'vehicle.lincoln.mkz_2017'
param weather = 'ClearNoon'

intersection = Uniform(*filter(lambda i: i.isSignalized and any(m.type is ManeuverType.LEFT_TURN for m in i.maneuvers), network.intersections))

egoManeuver = Uniform(*filter(lambda m: m.type is ManeuverType.LEFT_TURN, intersection.maneuvers))
egoInitLane = egoManeuver.startLane
egoSpawnPt = new OrientedPoint in egoInitLane.centerline
egoTrajectory = [egoInitLane, egoManeuver.connectingLane, egoManeuver.endLane]

pedLane = Uniform(*intersection.incomingLanes)
pedSpawnPt = new OrientedPoint at pedLane.centerline[-1]

param OPT_EGO_SPEED = Range(5, 7)
param OPT_BRAKE_DIST = Range(5, 10)

behavior EgoBehavior():
    try:
        do FollowTrajectoryBehavior(trajectory=egoTrajectory, target_speed=globalParameters.OPT_EGO_SPEED)
    interrupt when withinDistanceToAnyPedestrians(self, globalParameters.OPT_BRAKE_DIST):
        take SetThrottleAction(0)
        take SetBrakeAction(1)
    terminate

ego = new Car at egoSpawnPt,
    with regionContainedIn None,
    with blueprint MODEL,
    with behavior EgoBehavior()

param PED_MIN_SPEED = 1.0
param PED_THRESHOLD = 20

behavior PedestrianBehavior(min_speed, threshold):
    do CrossingBehavior(ego, min_speed, threshold)

ped = new Pedestrian at pedSpawnPt,
    facing 90 deg relative to pedSpawnPt.heading,
    with regionContainedIn None,
    with behavior PedestrianBehavior(globalParameters.PED_MIN_SPEED, globalParameters.PED_THRESHOLD)

monitor TrafficLightMonitor():
    freezeTrafficLights()
    while True:
        if withinDistanceToTrafficLight(ego, 30):
            setClosestTrafficLightStatus(ego, "green")
        wait

require monitor TrafficLightMonitor()
require 30 <= (distance from egoSpawnPt to intersection) <= 40
terminate when (distance from ego to intersection > 20) and (ego in egoManeuver.endLane)