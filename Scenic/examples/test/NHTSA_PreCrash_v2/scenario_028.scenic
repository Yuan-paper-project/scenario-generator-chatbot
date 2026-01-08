description = "Ego vehicle turns left at a signalized intersection, cutting off an oncoming vehicle."
param map = localPath('../../assets/maps/CARLA/Town05.xodr')
param carla_map = 'Town05'
model scenic.simulators.carla.model
MODEL = 'vehicle.lincoln.mkz_2017'
param weather = 'ClearNoon'

intersection = Uniform(*filter(lambda i: i.is4Way and i.isSignalized, network.intersections))

egoManeuver = Uniform(*filter(lambda m: m.type is ManeuverType.LEFT_TURN, intersection.maneuvers))
egoInitLane = egoManeuver.startLane
egoSpawnPt = new OrientedPoint in egoInitLane.centerline
egoTrajectory = [egoInitLane, egoManeuver.connectingLane, egoManeuver.endLane]

advManeuver = Uniform(*filter(lambda m: m.type is ManeuverType.STRAIGHT, egoManeuver.conflictingManeuvers))
advInitLane = advManeuver.startLane
advSpawnPt = new OrientedPoint in advInitLane.centerline
advTrajectory = [advInitLane, advManeuver.connectingLane, advManeuver.endLane]

param EGO_SPEED = Range(7, 10)

behavior EgoBehavior(trajectory):
    do FollowTrajectoryBehavior(target_speed=globalParameters.EGO_SPEED, trajectory=trajectory)

ego = new Car at egoSpawnPt,
    with blueprint MODEL,
    with behavior EgoBehavior(egoTrajectory)

param ADV_SPEED = Range(7, 10)

behavior AdversaryBehavior(trajectory):
    do FollowTrajectoryBehavior(target_speed=globalParameters.ADV_SPEED, trajectory=trajectory)

adversary = new Car at advSpawnPt,
    with blueprint MODEL,
    with behavior AdversaryBehavior(advTrajectory)

EGO_INIT_DIST = [20, 30]
ADV_INIT_DIST = [20, 30]

require EGO_INIT_DIST[0] <= (distance from egoSpawnPt to intersection) <= EGO_INIT_DIST[1]
require ADV_INIT_DIST[0] <= (distance from advSpawnPt to intersection) <= ADV_INIT_DIST[1]

monitor TrafficLightControl():
    freezeTrafficLights()
    while True:
        if withinDistanceToTrafficLight(ego, 100):
            setClosestTrafficLightStatus(ego, "green")
        if withinDistanceToTrafficLight(adversary, 100):
            setClosestTrafficLightStatus(adversary, "green")
        wait

require monitor TrafficLightControl()

terminate when (distance from ego to egoSpawnPt) > 80 and (distance from adversary to advSpawnPt) > 80