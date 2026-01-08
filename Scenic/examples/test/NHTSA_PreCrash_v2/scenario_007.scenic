description = "Vehicle turns at an intersection in a rural area at night, then departs the road edge, with a 25 mph speed limit."
param map = localPath('../../assets/maps/CARLA/Town07.xodr')
param carla_map = 'Town07'
model scenic.simulators.carla.model
MODEL = 'vehicle.lincoln.mkz_2017'
param weather = 'ClearSunset'

intersection = Uniform(*network.intersections)

egoInitLane = Uniform(*intersection.incomingLanes)
egoManeuver = Uniform(*filter(lambda m: m.type in (ManeuverType.LEFT_TURN, ManeuverType.RIGHT_TURN), egoInitLane.maneuvers))
egoTrajectory = [egoInitLane, egoManeuver.connectingLane, egoManeuver.endLane]
egoSpawnPt = new OrientedPoint in egoInitLane.centerline

param EGO_SPEED = Range(7, 10)
param DEPART_THROTTLE = 0.4
param DEPART_STEER = 0.5

behavior DepartBehavior(throttle, steer):
    while True:
        take SetThrottleAction(throttle), SetSteerAction(steer)

behavior EgoBehavior(trajectory):
    do FollowTrajectoryBehavior(target_speed=globalParameters.EGO_SPEED, trajectory=trajectory)
    do DepartBehavior(globalParameters.DEPART_THROTTLE, globalParameters.DEPART_STEER) for 5 seconds

ego = new Car at egoSpawnPt,
    with blueprint MODEL,
    with behavior EgoBehavior(egoTrajectory)

TERM_DIST = 10

monitor TrafficLightMonitor():
    freezeTrafficLights()
    while True:
        if withinDistanceToTrafficLight(ego, 50):
            setClosestTrafficLightStatus(ego, "green")
        wait

require monitor TrafficLightMonitor()
terminate when (ego not in network.roads) and (distance to egoSpawnPt > TERM_DIST)