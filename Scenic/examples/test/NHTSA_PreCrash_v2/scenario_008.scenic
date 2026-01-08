description = "Ego vehicle drives straight in a rural area at night under clear weather, departing the road at a non-junction area with a high speed limit."
param map = localPath('../../assets/maps/CARLA/Town07.xodr')
param carla_map = 'Town07'
model scenic.simulators.carla.model
MODEL = 'vehicle.lincoln.mkz_2017'
param weather = 'ClearSunset'

egoRoad = Uniform(*filter(lambda r: r.speedLimit is not None and r.speedLimit > 20, network.roads))
egoInitLane = Uniform(*egoRoad.lanes)
egoSpawnPt = new OrientedPoint on egoInitLane.rightEdge
egoTrajectory = [egoInitLane]

param EGO_SPEED = Range(15, 20)
param DEPART_STEER = 0.5
param DRIVE_DURATION = Range(3, 5)

behavior EgoBehavior(trajectory):
	try:
		do FollowTrajectoryBehavior(target_speed=globalParameters.EGO_SPEED, trajectory=trajectory) for globalParameters.DRIVE_DURATION seconds
	interrupt when True:
		while True:
			take SetSteerAction(globalParameters.DEPART_STEER)
			take SetThrottleAction(0.6)

ego = new Car at egoSpawnPt,
	with blueprint MODEL,
	with behavior EgoBehavior(egoTrajectory)

require (distance from egoSpawnPt to intersection) > 50
terminate after 10 seconds