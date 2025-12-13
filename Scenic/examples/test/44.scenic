description = "Vehicle is going straight in a rural area, in daylight, under clear weather conditions, on a dry road with a posted speed limit of 55 mph or more, and then loses control due to catastrophic component failure at a non-junction and runs off the road. Failure of tires, brakes, power train, steering system, and wheels contributed to about 95 percent of these crashes, with tires alone accounting for 62 percent of vehicle failure crashes"
param map = localPath('../../assets/maps/CARLA/Town05.xodr')
param carla_map = 'Town05'
model scenic.simulators.carla.model
MODEL = 'vehicle.mini.cooper_s_2021'
param EGO_SPEED = Range(25, 30) # Adjusted to 55 mph (approx 24.58 m/s) or more
param EGO_BRAKE = Range(0.5, 1.0)
param OPT_GEO_Y_DISTANCE = Range(20, 35)
SAFE_DIST = 10

intersection = Uniform(*filter(lambda i: i.is4Way and not i.isSignalized, network.intersections))
egoInitLane = Uniform(*intersection.incomingLanes)
egoManeuver = Uniform(*filter(lambda m: m.type is ManeuverType.STRAIGHT, egoInitLane.maneuvers))
egoTrajectory = egoInitLane.centerline + egoManeuver.connectingLane.centerline + egoManeuver.endLane.centerline
egoSpawnPt = new OrientedPoint in egoManeuver.startLane.centerline

behavior EgoBehavior(trajectory):
    do FollowTrajectoryBehavior(target_speed=globalParameters.EGO_SPEED, trajectory=trajectory)

ego = new Car at egoSpawnPt,
    with blueprint MODEL,
    with behavior EgoBehavior(trajectory=egoTrajectory)

param LEAD_SPEED = Range(25,30) # Adjusted to 55 mph (approx 24.58 m/s) or more
param LEAD_BRAKE = Range(0.5, 1.0)

# SAFE_DIST = 10 (already defined)
behavior LeadBehavior():
    try:
        do FollowLaneBehavior(globalParameters.LEAD_SPEED)
    interrupt when withinDistanceToAnyCars(self, SAFE_DIST):
        take SetBrakeAction(globalParameters.LEAD_BRAKE)
obstacle =  new Trash on lane.centerline
lead =  new Car following roadDirection from obstacle for Range(-50, -30),
        with behavior LeadBehavior()
IntSpawnPt = new OrientedPoint following egoInitLane.orientation from egoSpawnPt for globalParameters.OPT_GEO_Y_DISTANCE
INIT_DIST = 500 # Adjusted to ensure event is far from an intersection (non-junction, rural)
TERM_DIST = 30
require (distance to intersection) > INIT_DIST
terminate when (distance to obstacle) > TERM_DIST