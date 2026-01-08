description = "Ego vehicle stops at a stop sign at a 25 mph intersection and proceeds against crossing traffic."
param map = localPath('../../assets/maps/CARLA/Town05.xodr')
param carla_map = 'Town05'
model scenic.simulators.carla.model
MODEL = 'vehicle.lincoln.mkz_2017'
param weather = 'ClearNoon'

intersection = Uniform(*filter(lambda i: i.is4Way, network.intersections))

egoManeuver = Uniform(*filter(lambda m: m.type is ManeuverType.STRAIGHT, intersection.maneuvers))
egoInitLane = egoManeuver.startLane
egoSpawnPt = new OrientedPoint in egoInitLane.centerline
egoTrajectory = [egoInitLane, egoManeuver.connectingLane, egoManeuver.endLane]

advManeuver = Uniform(*filter(lambda m: m.type is ManeuverType.STRAIGHT, egoManeuver.conflictingManeuvers))
advInitLane = advManeuver.startLane
advSpawnPt = new OrientedPoint in advInitLane.centerline
advTrajectory = [advInitLane, advManeuver.connectingLane, advManeuver.endLane]

param OPT_EGO_SPEED = Range(9, 11)
param OPT_STOP_TIME = Range(2, 4)
param OPT_SAFETY_DIST = 10

behavior EgoBehavior(trajectory):
    try:
        do FollowLaneBehavior(target_speed=globalParameters.OPT_EGO_SPEED) until (distance from self to intersection < 5)
        take SetBrakeAction(1)
        take SetThrottleAction(0)
        wait for globalParameters.OPT_STOP_TIME seconds
        do FollowTrajectoryBehavior(target_speed=globalParameters.OPT_EGO_SPEED, trajectory=trajectory)
    interrupt when withinDistanceToAnyCars(self, globalParameters.OPT_SAFETY_DIST):
        take SetBrakeAction(1)
        take SetThrottleAction(0)

ego = new Car at egoSpawnPt,
    with blueprint MODEL,
    with behavior EgoBehavior(egoTrajectory)

param ADV_SPEED = Range(7, 10)

behavior AdversaryBehavior(trajectory):
    do FollowTrajectoryBehavior(target_speed=globalParameters.ADV_SPEED, trajectory=trajectory)

adversary = new Car at advSpawnPt,
    with blueprint MODEL,
    with behavior AdversaryBehavior(advTrajectory)

require 25 <= (distance from egoSpawnPt to intersection) <= 35
require 25 <= (distance from advSpawnPt to intersection) <= 35

monitor TrafficLightControl():
    freezeTrafficLights()
    while True:
        if withinDistanceToTrafficLight(ego, 100):
            setClosestTrafficLightStatus(ego, "green")
        if withinDistanceToTrafficLight(adversary, 100):
            setClosestTrafficLightStatus(adversary, "green")
        wait

require monitor TrafficLightControl()

terminate when (distance from ego to egoSpawnPt) > 70