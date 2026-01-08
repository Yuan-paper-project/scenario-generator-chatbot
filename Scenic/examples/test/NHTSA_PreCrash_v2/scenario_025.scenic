description = "Ego vehicle approaches a slower lead vehicle while driving straight in an urban area with a high speed limit under clear daylight."
param map = localPath('../../assets/maps/CARLA/Town05.xodr')
param carla_map = 'Town05'
model scenic.simulators.carla.model
MODEL = 'vehicle.lincoln.mkz_2017'
param weather = 'ClearNoon'

param OPT_LEAD_DISTANCE = Range(15, 30)

egoLane = Uniform(*network.lanes)
egoSpawnPt = new OrientedPoint in egoLane.centerline
leadSpawnPt = new OrientedPoint following egoLane.orientation from egoSpawnPt for globalParameters.OPT_LEAD_DISTANCE
egoTrajectory = [egoLane]

param EGO_SPEED = Range(15, 20)
param EGO_BRAKE = 1.0
param SAFETY_DISTANCE = 10

behavior EgoBehavior(speed, trajectory, safety_dist, brake_val):
	try:
		do FollowTrajectoryBehavior(target_speed=speed, trajectory=trajectory)
	interrupt when withinDistanceToObjsInLane(self, safety_dist):
		take SetBrakeAction(brake_val)

ego = new Car at egoSpawnPt,
	with blueprint MODEL,
	with behavior EgoBehavior(globalParameters.EGO_SPEED, egoTrajectory, globalParameters.SAFETY_DISTANCE, globalParameters.EGO_BRAKE)

param LEAD_SPEED = Range(5, 10)

behavior LeadVehicleBehavior(speed):
	do FollowLaneBehavior(target_speed=speed)

lead_vehicle = new Car at leadSpawnPt,
	with blueprint MODEL,
	with behavior LeadVehicleBehavior(globalParameters.LEAD_SPEED)

require 15 <= (distance from egoSpawnPt to leadSpawnPt) <= 30