description = "Ego vehicle drives straight in an urban area at 35 mph and runs a red light."
param map = localPath('../../../assets/maps/CARLA/Town05.xodr')
param carla_map = 'Town05'
model scenic.simulators.carla.model
MODEL = 'vehicle.lincoln.mkz_2017'
param weather = 'ClearNoon'

intersection = Uniform(*filter(lambda i: i.isSignalized, network.intersections))
egoInitLane = Uniform(*filter(lambda l: any(m.type is ManeuverType.STRAIGHT for m in l.maneuvers), intersection.incomingLanes))
egoManeuver = Uniform(*filter(lambda m: m.type is ManeuverType.STRAIGHT, egoInitLane.maneuvers))
egoTrajectory = [egoInitLane, egoManeuver.connectingLane, egoManeuver.endLane]
egoSpawnPt = new OrientedPoint in egoInitLane.centerline

param EGO_SPEED = 15.64

behavior EgoBehavior(trajectory):
	do FollowTrajectoryBehavior(target_speed=globalParameters.EGO_SPEED, trajectory=trajectory)

ego = new Car at egoSpawnPt,
	with blueprint MODEL,  
	with behavior EgoBehavior(egoTrajectory),
	with rolename 'hero'
 
monitor TrafficLightControl():
    freezeTrafficLights()
    while True:
        if withinDistanceToTrafficLight(ego, 100):
            setClosestTrafficLightStatus(ego, 'red')
        wait

require monitor TrafficLightControl()
require 30 <= (distance from egoSpawnPt to intersection) <= 50
terminate when (distance from ego to egoSpawnPt) > 70