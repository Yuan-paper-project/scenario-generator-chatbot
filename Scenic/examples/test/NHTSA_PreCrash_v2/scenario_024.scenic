description = "Ego vehicle follows an accelerating lead vehicle straight through an urban intersection."
param map = localPath('../../assets/maps/CARLA/Town05.xodr')
param carla_map = 'Town05'
model scenic.simulators.carla.model
MODEL = 'vehicle.lincoln.mkz_2017'
param weather = 'ClearNoon'

intersection = Uniform(*filter(lambda i: any(m.type is ManeuverType.STRAIGHT for m in i.maneuvers), network.intersections))
egoManeuver = Uniform(*filter(lambda m: m.type is ManeuverType.STRAIGHT, intersection.maneuvers))
egoInitLane = egoManeuver.startLane
egoTrajectory = [egoInitLane, egoManeuver.connectingLane, egoManeuver.endLane]
leadTrajectory = egoTrajectory
leadSpawnPt = new OrientedPoint in egoInitLane.centerline
egoSpawnPt = new OrientedPoint behind leadSpawnPt by Range(5, 10)

param EGO_SPEED = Range(12, 15)

behavior EgoBehavior(trajectory):
	do FollowTrajectoryBehavior(target_speed=globalParameters.EGO_SPEED, trajectory=trajectory)

ego = new Car at egoSpawnPt,
	with blueprint MODEL,
	with behavior EgoBehavior(egoTrajectory)

param ADV_SPEED = Range(20, 25)

behavior AdversaryBehavior(trajectory):
	do FollowTrajectoryBehavior(target_speed=globalParameters.ADV_SPEED, trajectory=trajectory)

adversary = new Car at leadSpawnPt,
	with blueprint MODEL,
	with behavior AdversaryBehavior(leadTrajectory)

param TERM_DIST = 70

monitor TrafficLights():
    freezeTrafficLights()
    while True:
        if withinDistanceToTrafficLight(ego, 50):
            setClosestTrafficLightStatus(ego, "green")
        if withinDistanceToTrafficLight(adversary, 50):
            setClosestTrafficLightStatus(adversary, "green")
        wait

require monitor TrafficLights()
require 5 <= (distance from egoSpawnPt to leadSpawnPt) <= 10
terminate when (distance from ego to egoSpawnPt) > globalParameters.TERM_DIST