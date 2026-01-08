description = "Ego vehicle turning right in an urban area encounters a pedalcyclist."
param map = localPath('../../assets/maps/CARLA/Town05.xodr')
param carla_map = 'Town05'
model scenic.simulators.carla.model
MODEL = 'vehicle.lincoln.mkz_2017'
param weather = 'ClearNoon'

intersection = Uniform(*filter(lambda i: any(m.type is ManeuverType.RIGHT_TURN and m.conflictingManeuvers for m in i.maneuvers), network.intersections))
egoManeuver = Uniform(*filter(lambda m: m.type is ManeuverType.RIGHT_TURN and m.conflictingManeuvers, intersection.maneuvers))
egoInitLane = egoManeuver.startLane
egoSpawnPt = new OrientedPoint in egoInitLane.centerline
egoTrajectory = [egoInitLane, egoManeuver.connectingLane, egoManeuver.endLane]

bikeManeuver = Uniform(*egoManeuver.conflictingManeuvers)
bikeInitLane = bikeManeuver.startLane
bikeSpawnPt = new OrientedPoint in bikeInitLane.centerline
bikeTrajectory = [bikeInitLane, bikeManeuver.connectingLane, bikeManeuver.endLane]

param EGO_SPEED = Range(7, 10)

behavior EgoBehavior(trajectory):
    do FollowTrajectoryBehavior(target_speed=globalParameters.EGO_SPEED, trajectory=trajectory)

ego = new Car at egoSpawnPt,
    with blueprint MODEL,
    with behavior EgoBehavior(egoTrajectory)

param BICYCLE_SPEED = Range(4, 7)

behavior BicycleBehavior(trajectory):
    do FollowTrajectoryBehavior(target_speed=globalParameters.BICYCLE_SPEED, trajectory=trajectory)

bicycle = new Bicycle at bikeSpawnPt,
    with behavior BicycleBehavior(bikeTrajectory),
    with regionContainedIn None

monitor TrafficLights():
    freezeTrafficLights()
    while True:
        if withinDistanceToTrafficLight(ego, 100):
            setClosestTrafficLightStatus(ego, "green")
        if withinDistanceToTrafficLight(bicycle, 100):
            setClosestTrafficLightStatus(bicycle, "green")
        wait

require monitor TrafficLights()
require 15 <= (distance from egoSpawnPt to intersection) <= 25
require 10 <= (distance from bikeSpawnPt to intersection) <= 20

terminate when (distance from ego to egoSpawnPt) > 50