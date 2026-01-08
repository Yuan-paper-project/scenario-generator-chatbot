description = "Ego vehicle drifts and encroaches into an oncoming vehicle while traveling straight in a rural area."
param map = localPath('../../assets/maps/CARLA/Town07.xodr')
param carla_map = 'Town07'
model scenic.simulators.carla.model
MODEL = 'vehicle.lincoln.mkz_2017'
param weather = 'ClearNoon'

roadsWithOppositeLanes = filter(lambda r: r.forwardLanes and r.backwardLanes, network.roads)
targetRoad = Uniform(*roadsWithOppositeLanes)
egoLane = targetRoad.forwardLanes.lanes[0]
advLane = targetRoad.backwardLanes.lanes[0]
egoSpawnPt = new OrientedPoint on egoLane.centerline
advSpawnPt = new OrientedPoint on advLane.centerline
require 60 <= (distance from egoSpawnPt to advSpawnPt) <= 100
require (angle to advSpawnPt from egoSpawnPt) < 10
require (relative heading of advSpawnPt from egoSpawnPt) > 170
egoTrajectory = [egoLane]
advTrajectory = [advLane]

param EGO_SPEED = Range(7, 10)
param DRIFT_DIST = Range(15, 25)

behavior EgoBehavior(trajectory, target_lane_sec):
	try:
		do FollowTrajectoryBehavior(target_speed=globalParameters.EGO_SPEED, trajectory=trajectory) until (distance from self to egoSpawnPt) > globalParameters.DRIFT_DIST
		do LaneChangeBehavior(laneSectionToSwitch=target_lane_sec, is_oppositeTraffic=True, target_speed=globalParameters.EGO_SPEED)
		do FollowLaneBehavior(target_speed=globalParameters.EGO_SPEED, is_oppositeTraffic=True)
	interrupt when withinDistanceToAnyCars(self, 5):
		take SetBrakeAction(1)

ego = new Car at egoSpawnPt,
	with blueprint MODEL,
	with behavior EgoBehavior(egoTrajectory, advLane.sections[0])

param ADV_SPEED = Range(7, 10)

behavior AdversaryBehavior(trajectory):
	do FollowTrajectoryBehavior(target_speed=globalParameters.ADV_SPEED, trajectory=trajectory)

adversary = new Car at advSpawnPt,
	with blueprint MODEL,
	with behavior AdversaryBehavior(advTrajectory)

param TERMINATE_DIST = 120

terminate when (distance from ego to egoSpawnPt) > globalParameters.TERMINATE_DIST