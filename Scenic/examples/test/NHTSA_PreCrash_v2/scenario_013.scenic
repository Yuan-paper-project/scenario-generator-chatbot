description = "Ego vehicle navigating an intersection."
param map = localPath('../../assets/maps/CARLA/Town05.xodr')
param carla_map = 'Town05'
model scenic.simulators.carla.model
MODEL = 'vehicle.lincoln.mkz_2017'
param weather = 'ClearNoon'

intersection = Uniform(*filter(lambda i: len(i.incomingLanes) >= 2, network.intersections))

egoLane = Uniform(*intersection.incomingLanes)
egoSpawnPt = new OrientedPoint in egoLane.centerline

advLane = Uniform(*filter(lambda l: l != egoLane, intersection.incomingLanes))
advSpawnPt = new OrientedPoint in advLane.centerline

param EGO_SPEED = Range(7, 10)

behavior EgoBehavior(speed):
	do FollowLaneBehavior(target_speed=speed)

ego = new Car at egoSpawnPt,
	with blueprint MODEL,
	with behavior EgoBehavior(globalParameters.EGO_SPEED)

param ADV_SPEED = Range(7, 10)

advManeuver = Uniform(*filter(lambda m: m.type != ManeuverType.STRAIGHT, advLane.maneuvers))
advTrajectory = [advLane] + list(advManeuver.connectingLanes)

behavior AdversaryBehavior(trajectory):
	do FollowTrajectoryBehavior(target_speed=globalParameters.ADV_SPEED, trajectory=trajectory)

adversary = new Car at advSpawnPt,
	with blueprint MODEL,
	with behavior AdversaryBehavior(advTrajectory)

monitor TrafficLights():
	freezeTrafficLights()
	while True:
		if withinDistanceToTrafficLight(ego, 50):
			setClosestTrafficLightStatus(ego, "green")
		if withinDistanceToTrafficLight(adversary, 50):
			setClosestTrafficLightStatus(adversary, "green")
		wait

EGO_INIT_DIST = [25, 30]
ADV_INIT_DIST = [15, 20]
TERM_DIST = 70

require monitor TrafficLights()
require EGO_INIT_DIST[0] <= (distance from egoSpawnPt to intersection) <= EGO_INIT_DIST[1]
require ADV_INIT_DIST[0] <= (distance from advSpawnPt to intersection) <= ADV_INIT_DIST[1]
terminate when (distance to egoSpawnPt) > TERM_DIST