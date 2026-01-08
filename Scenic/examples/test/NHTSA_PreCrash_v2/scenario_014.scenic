description = "Ego vehicle going straight in an urban area encounters a pedalcyclist."
param map = localPath('../../assets/maps/CARLA/Town05.xodr')
param carla_map = 'Town05'
model scenic.simulators.carla.model
MODEL = 'vehicle.lincoln.mkz_2017'
param weather = 'ClearNoon'

egoLane = Uniform(*network.lanes)
egoSpawnPt = new OrientedPoint on egoLane.centerline
egoTrajectory = [egoLane]

# Define a reference point ahead of the ego vehicle to position the bicycle
# Using the 'following' specifier to ensure the point follows the road geometry
leadPt = new OrientedPoint following egoLane.orientation from egoSpawnPt for Range(20, 30)

# Position the bicycle relative to the lead point, shifted to the right to simulate the lane edge
bicycleSpawnPt = new OrientedPoint right of leadPt by 0.8

param EGO_SPEED = Range(7, 10)

behavior EgoBehavior(trajectory):
    do FollowTrajectoryBehavior(target_speed=globalParameters.EGO_SPEED, trajectory=trajectory)

ego = new Car at egoSpawnPt,
    with blueprint MODEL,
    with behavior EgoBehavior(egoTrajectory)

param BICYCLE_SPEED = Range(4, 6)

behavior BicycleBehavior(speed):
    do FollowLaneBehavior(target_speed=speed)

bicycle = new Bicycle at bicycleSpawnPt,
    with behavior BicycleBehavior(globalParameters.BICYCLE_SPEED),
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
require ego can see bicycle
terminate when (distance from ego to bicycleSpawnPt) > 50
terminate after 40 seconds