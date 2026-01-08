description = "Vehicle performs an unprotected left turn, cutting off an oncoming vehicle at anS uncontrolled intersection."
param map = localPath('../../../assets/maps/CARLA/Town05.xodr')
param carla_map = 'Town05'
model scenic.simulators.carla.model
MODEL = 'vehicle.lincoln.mkz_2017'
param weather = 'ClearNoon'

intersection = Uniform(*filter(lambda i: not i.isSignalized, network.intersections))
egoInitLane = Uniform(*filter(lambda l: any(m.type is ManeuverType.LEFT_TURN for m in l.maneuvers) and any(m.type is ManeuverType.STRAIGHT for m in l.maneuvers), intersection.incomingLanes))
egoManeuver = Uniform(*filter(lambda m: m.type is ManeuverType.LEFT_TURN, egoInitLane.maneuvers))
egoSpawnPt = new OrientedPoint in egoInitLane.centerline
egoTrajectory = [egoInitLane, egoManeuver.connectingLane, egoManeuver.endLane]
egoStraightManeuver = Uniform(*filter(lambda m: m.type is ManeuverType.STRAIGHT, egoInitLane.maneuvers))
advManeuver = Uniform(*filter(lambda m: m.type is ManeuverType.STRAIGHT, egoStraightManeuver.reverseManeuvers))
advInitLane = advManeuver.startLane
advSpawnPt = new OrientedPoint in advInitLane.centerline
advTrajectory = [advInitLane, advManeuver.connectingLane, advManeuver.endLane]

param EGO_SPEED = Range(7, 10)

behavior EgoBehavior(trajectory):
    do FollowTrajectoryBehavior(target_speed=globalParameters.EGO_SPEED, trajectory=trajectory)

ego = new Car at egoSpawnPt,
    with blueprint MODEL,
    with behavior EgoBehavior(egoTrajectory)

param ADV_SPEED = Range(7, 10)

behavior AdversaryBehavior(trajectory):
    do FollowTrajectoryBehavior(target_speed=globalParameters.ADV_SPEED, trajectory=trajectory)

adversary = new Car at advSpawnPt,
    with blueprint MODEL,
    with behavior AdversaryBehavior(advTrajectory)

EGO_DIST = [15, 25]
ADV_DIST = [15, 25]
EGO_ADV_DIST = [30, 50]
TERM_DIST = 60

require EGO_DIST[0] <= (distance from egoSpawnPt to intersection) <= EGO_DIST[1]
require ADV_DIST[0] <= (distance from advSpawnPt to intersection) <= ADV_DIST[1]
require EGO_ADV_DIST[0] <= (distance from egoSpawnPt to advSpawnPt) <= EGO_ADV_DIST[1]

terminate when (distance to egoSpawnPt) > TERM_DIST