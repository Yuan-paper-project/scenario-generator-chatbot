description = "Ego vehicle approaches a stopped lead vehicle at an urban intersection (35mph limit)."
param map = localPath('../../assets/maps/CARLA/Town05.xodr')
param carla_map = 'Town05'
model scenic.simulators.carla.model
MODEL = 'vehicle.lincoln.mkz_2017'
param weather = 'ClearNoon'

intersection = Uniform(*filter(lambda i: i.is4Way, network.intersections))
egoManeuver = Uniform(*filter(lambda m: m.type is ManeuverType.STRAIGHT, intersection.maneuvers))
egoInitLane = egoManeuver.startLane

advSpawnPt = new OrientedPoint on egoInitLane.centerline
egoSpawnPt = new OrientedPoint behind advSpawnPt by Range(10, 15)

egoTrajectory = [egoInitLane, egoManeuver.connectingLane, egoManeuver.endLane]

param EGO_SPEED = Range(10, 15)

behavior EgoBehavior(trajectory):
	do FollowTrajectoryBehavior(target_speed=globalParameters.EGO_SPEED, trajectory=trajectory)

ego = new Car at egoSpawnPt,
	with blueprint MODEL,
	with behavior EgoBehavior(egoTrajectory)

param ADV_SPEED = 0

behavior AdversaryBehavior():
    do FollowLaneBehavior(globalParameters.ADV_SPEED)

adversary = new Car at advSpawnPt,
    with blueprint MODEL,
    with behavior AdversaryBehavior()

TERM_DIST = 50

monitor TrafficLights():
    freezeTrafficLights()
    while True:
        if withinDistanceToTrafficLight(ego, 100):
            setClosestTrafficLightStatus(ego, "green")
        wait

require monitor TrafficLights()
require 10 <= (distance from egoSpawnPt to advSpawnPt) <= 15
terminate when (distance to egoSpawnPt) > TERM_DIST