description = "Ego vehicle stops at a stop sign, then turns left against crossing traffic at a rural intersection with a 35 mph speed limit."
param map = localPath('../../assets/maps/CARLA/Town07.xodr')
param carla_map = 'Town07'
model scenic.simulators.carla.model
MODEL = 'vehicle.lincoln.mkz_2017'
param weather = 'ClearNoon'

intersection = Uniform(*filter(lambda i: i.is4Way, network.intersections))

egoManeuver = Uniform(*filter(lambda m: m.type is ManeuverType.LEFT_TURN, intersection.maneuvers))
egoInitLane = egoManeuver.startLane
egoSpawnPt = new OrientedPoint in egoInitLane.centerline
egoTrajectory = [egoInitLane, egoManeuver.connectingLane, egoManeuver.endLane]

advManeuver = Uniform(*filter(lambda m: m.type is ManeuverType.STRAIGHT, intersection.maneuvers))
require advManeuver in egoManeuver.conflictingManeuvers
require advManeuver.startLane.road != egoInitLane.road
advInitLane = advManeuver.startLane
advSpawnPt = new OrientedPoint in advInitLane.centerline
advTrajectory = [advInitLane, advManeuver.connectingLane, advManeuver.endLane]

param EGO_SPEED = Range(7, 10)
param STOP_DURATION = Range(2, 4)
param SAFETY_DIST = 8

behavior EgoBehavior(trajectory):
    try:
        do FollowLaneBehavior(target_speed=globalParameters.EGO_SPEED) until (distance from self to intersection < 5)
        do FollowLaneBehavior(target_speed=0) for globalParameters.STOP_DURATION seconds
        do FollowTrajectoryBehavior(target_speed=globalParameters.EGO_SPEED, trajectory=trajectory)
    interrupt when withinDistanceToAnyCars(self, globalParameters.SAFETY_DIST):
        take SetBrakeAction(1.0)

ego = new Car at egoSpawnPt,
    with blueprint MODEL,
    with behavior EgoBehavior(egoTrajectory)

param ADV_SPEED = Range(7, 10)

behavior AdversaryBehavior(trajectory):
    do FollowTrajectoryBehavior(target_speed=globalParameters.ADV_SPEED, trajectory=trajectory)

adversary = new NPCCar at advSpawnPt,
    with blueprint MODEL,
    with behavior AdversaryBehavior(advTrajectory)

monitor TrafficManager():
    freezeTrafficLights()
    while True:
        if withinDistanceToTrafficLight(ego, 100):
            setClosestTrafficLightStatus(ego, "green")
        if withinDistanceToTrafficLight(adversary, 100):
            setClosestTrafficLightStatus(adversary, "green")
        wait

require monitor TrafficManager()

EGO_INIT_DIST = [20, 25]
ADV_INIT_DIST = [15, 20]
TERM_DIST = 70

require EGO_INIT_DIST[0] <= (distance from egoSpawnPt to intersection) <= EGO_INIT_DIST[1]
require ADV_INIT_DIST[0] <= (distance from advSpawnPt to intersection) <= ADV_INIT_DIST[1]

terminate when (distance from ego to egoSpawnPt) > TERM_DIST