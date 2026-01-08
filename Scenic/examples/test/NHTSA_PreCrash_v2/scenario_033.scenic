description = "Ego vehicle turns left at an urban intersection, performing evasive action to avoid an obstacle, in daylight and clear weather."
param map = localPath('../../../assets/maps/CARLA/Town05.xodr')
param carla_map = 'Town05'
model scenic.simulators.carla.model
MODEL = 'vehicle.lincoln.mkz_2017'
param weather = 'ClearNoon'

intersection = Uniform(*network.intersections)
egoInitLane = Uniform(*intersection.incomingLanes)
egoManeuver = Uniform(*filter(lambda m: m.type is ManeuverType.LEFT_TURN, egoInitLane.maneuvers))
egoTrajectory = [egoInitLane, egoManeuver.connectingLane, egoManeuver.endLane]
egoSpawnPt = new OrientedPoint in egoInitLane.centerline
obstacleSpawnPt = new OrientedPoint in egoManeuver.connectingLane.centerline

param EGO_SPEED = Range(6, 8)
param SAFETY_DISTANCE = 12

behavior EgoBehavior(trajectory, speed, safety_dist):
    try:
        do FollowTrajectoryBehavior(target_speed=speed, trajectory=trajectory)
    interrupt when withinDistanceToAnyObjs(self, safety_dist):
        take SetBrakeAction(1.0)

ego = new Car at egoSpawnPt,
    with blueprint MODEL,
    with rolename 'hero',  
    with behavior EgoBehavior(egoTrajectory, globalParameters.EGO_SPEED, globalParameters.SAFETY_DISTANCE)

obstacle = new Trash at obstacleSpawnPt

monitor TrafficLights():
    freezeTrafficLights()
    while True:
        if withinDistanceToTrafficLight(ego, 100):
            setClosestTrafficLightStatus(ego, "green")
        wait

require monitor TrafficLights()
require 15 <= (distance from egoSpawnPt to intersection) <= 25

terminate when (distance from ego to egoSpawnPt) > 40