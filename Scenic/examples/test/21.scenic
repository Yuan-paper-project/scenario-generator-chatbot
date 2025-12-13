description = "Ego vehicle yields to another vehicle while executing a maneuver at a four-way intersection."
param map = localPath('../../assets/maps/CARLA/Town05.xodr')
param carla_map = 'Town05'
model scenic.simulators.carla.model
MODEL = 'vehicle.mini.cooper_s_2021'
param EGO_SPEED = Range(7, 10)
param EGO_BRAKE = Range(0.5, 1.0)
SAFE_DIST = 20
behavior EgoBehavior(trajectory):
    try:
        do FollowTrajectoryBehavior(target_speed=globalParameters.EGO_SPEED,trajectory=trajectory)
    interrupt when withinDistanceToAnyObjs(self, SAFE_DIST):
        take SetBrakeAction(globalParameters.EGO_BRAKE)
param ADV_SPEED = Range(7, 10)
behavior AdvBehavior(trajectory):
    do FollowTrajectoryBehavior(target_speed=globalParameters.ADV_SPEED, trajectory=trajectory)
intersection = Uniform(*filter(lambda i: i.is4Way, network.intersections))
egoInitLane = Uniform(*intersection.incomingLanes)
egoManeuver = Uniform(*egoInitLane.maneuvers)
egoTrajectory = [egoManeuver.startLane, egoManeuver.connectingLane, egoManeuver.endLane]
egoSpawnPt = new OrientedPoint in egoManeuver.startLane.centerline
advManeuver = Uniform(*egoManeuver.conflictingManeuvers)
advTrajectory = [advManeuver.startLane, advManeuver.connectingLane, advManeuver.endLane]
advSpawnPt = new OrientedPoint in advManeuver.startLane.centerline
ego = new Car at egoSpawnPt,
    with blueprint MODEL,
    with behavior EgoBehavior(egoTrajectory)
adv = new Car at advSpawnPt,
    with blueprint MODEL,
    with behavior AdvBehavior(advTrajectory)
EGO_INIT_DIST = [20, 25]
ADV_INIT_DIST = [15, 20]
TERM_DIST = 70
require EGO_INIT_DIST[0] <= (distance to intersection) <= EGO_INIT_DIST[1]
require ADV_INIT_DIST[0] <= (distance from adv to intersection) <= ADV_INIT_DIST[1]
terminate when (distance to egoSpawnPt) > TERM_DIST