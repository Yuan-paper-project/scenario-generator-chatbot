description = "Ego vehicle backs up in an urban area, then departs the road into a driveway/alley."
param map = localPath('../../../assets/maps/CARLA/Town05.xodr')
param carla_map = 'Town05'
model scenic.simulators.carla.model
MODEL = 'vehicle.lincoln.mkz_2017'
param weather = 'ClearNoon'

intersection = Uniform(*filter(lambda i: i.is3Way, network.intersections))
egoManeuver = Uniform(*filter(lambda m: m.type is ManeuverType.RIGHT_TURN, intersection.maneuvers))
egoInitLane = egoManeuver.startLane

drivewayEntrance = egoInitLane.centerline[-1]
egoSpawnPt = new OrientedPoint following egoInitLane.orientation from drivewayEntrance for Range(6, 10)

egoTrajectory = [egoInitLane, egoManeuver.connectingLane, egoManeuver.endLane]

param EGO_BACKUP_SPEED = 2.0
param EGO_DEPART_SPEED = 5.0

behavior EgoBehavior(trajectory, target_pt):
    take SetReverseAction(True)
    while (distance from self to target_pt) > 1.5:
        take SetSpeedAction(globalParameters.EGO_BACKUP_SPEED)
    
    take SetReverseAction(False)
    take SetBrakeAction(1.0)
    wait for 1.0 seconds
    
    do FollowTrajectoryBehavior(target_speed=globalParameters.EGO_DEPART_SPEED, trajectory=trajectory)

ego = new Car at egoSpawnPt,
    with blueprint MODEL,
    with behavior EgoBehavior(egoTrajectory, drivewayEntrance)

monitor TrafficLights():
    freezeTrafficLights()
    while True:
        if withinDistanceToTrafficLight(ego, 100):
            setClosestTrafficLightStatus(ego, "green")
        wait

require monitor TrafficLights()
require 5 <= (distance from egoSpawnPt to drivewayEntrance) <= 15
terminate when (distance from ego to drivewayEntrance) > 20