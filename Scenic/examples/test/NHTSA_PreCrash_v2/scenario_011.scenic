description = "Ego vehicle drives straight in an urban area at 25 mph and encounters a pedestrian mid-block."
param map = localPath('../../assets/maps/CARLA/Town05.xodr')
param carla_map = 'Town05'
model scenic.simulators.carla.model
MODEL = 'vehicle.lincoln.mkz_2017'
param weather = 'ClearNoon'

egoRoad = Uniform(*network.roads)
egoLane = Uniform(*egoRoad.lanes)
egoSpawnPt = new OrientedPoint on egoLane.centerline
intermediatePt = new OrientedPoint following egoLane.orientation from egoSpawnPt for Range(20, 30)
pedSpawnPt = new OrientedPoint right of intermediatePt by Range(4, 6)

param EGO_SPEED = 11.176

behavior EgoBehavior(speed):
    do FollowLaneBehavior(target_speed=speed)

ego = new Car at egoSpawnPt,
    with blueprint MODEL,
    with behavior EgoBehavior(globalParameters.EGO_SPEED)

param PED_MIN_SPEED = 1.0
param PED_THRESHOLD = 20

behavior PedestrianBehavior(min_speed, threshold):
    do CrossingBehavior(ego, min_speed, threshold)

ped = new Pedestrian at pedSpawnPt,
    facing -90 deg relative to ego.heading,
    with regionContainedIn None,
    with behavior PedestrianBehavior(globalParameters.PED_MIN_SPEED, globalParameters.PED_THRESHOLD)

param MIN_INIT_DIST = 20
param MAX_INIT_DIST = 40
param TERM_DIST = 50

require globalParameters.MIN_INIT_DIST <= (distance from egoSpawnPt to pedSpawnPt) <= globalParameters.MAX_INIT_DIST
terminate when (distance from ego to ped) > 10 and (distance to egoSpawnPt) > globalParameters.TERM_DIST