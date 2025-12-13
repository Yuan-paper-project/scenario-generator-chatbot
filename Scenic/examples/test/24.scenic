description = "An ego vehicle runs a red light at an intersection and collides with another vehicle crossing laterally"
param map = localPath('../../assets/maps/CARLA/Town05.xodr')
param carla_map = 'Town05'
param ADV_DIST = Range(-25, -10)
param EGO_SPEED = Range(3, 5) #ADV2 nad ADV3 will have the same speed
model scenic.simulators.carla.model
MODEL = 'vehicle.mini.cooper_s_2021'
PED_MIN_SPEED = 1.0
PED_THRESHOLD = 20
behavior PedestrianBehavior():
    do CrossingBehavior(ego, PED_MIN_SPEED, PED_THRESHOLD)
behavior EgoBehavior(trajectory):
    do FollowLaneBehavior(trajectory, target_speed=globalParameters.EGO_SPEED)
intersection = Uniform(*filter(lambda i: i.is4Way or i.is3Way, network.intersections))
egoManeuver = Uniform(*filter(lambda m: m.type is ManeuverType.LEFT_TURN, intersection.maneuvers))
egoInitLane = egoManeuver.startLane
egoTrajectory = [egoInitLane, egoManeuver.connectingLane, egoManeuver.endLane]
egoSpawnPt = new OrientedPoint in egoInitLane.centerline
tempManeuver = Uniform(*filter(lambda m: m.type is ManeuverType.RIGHT_TURN, egoManeuver.reverseManeuvers))
tempInitLane = tempManeuver.startLane
tempSpawnPt = tempInitLane.centerline[-1]
ego = new Car at egoSpawnPt,
    with blueprint MODEL,
    with behavior EgoBehavior(egoTrajectory)
adversary = new Car at tempSpawnPt following roadDirection for globalParameters.ADV_DIST,
    with blueprint MODEL,
    with behavior AdversaryBehavior()
EGO_INIT_DIST = [20, 25]
TERM_DIST = 50
require EGO_INIT_DIST[0] <= (distance to intersection) <= EGO_INIT_DIST[1]
terminate when (distance to egoSpawnPt) > TERM_DIST