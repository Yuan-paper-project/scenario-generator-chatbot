description = "Ego vehicle leaves a parked position at night in an urban area and collides with an object on the road shoulder."
param map = localPath('../../../assets/maps/CARLA/Town05.xodr')
param carla_map = 'Town05'
model scenic.simulators.carla.model
MODEL = 'vehicle.lincoln.mkz_2017'
param weather = 'ClearNoon'

potentialShoulders = []
for lane in network.lanes:
    for section in lane.sections:
        if section._laneToRight is None:
            potentialShoulders.append(section)

egoSection = Uniform(*potentialShoulders)
egoSpawnPt = new OrientedPoint on egoSection.centerline

propSpawnPt = new OrientedPoint following egoSection.orientation from egoSpawnPt for Range(5, 10)

param EGO_SPEED = Range(5, 8)

behavior EgoBehavior(target_speed):
    do FollowLaneBehavior(target_speed=target_speed)

ego = new Car at egoSpawnPt,
    with blueprint MODEL,
    with behavior EgoBehavior(globalParameters.EGO_SPEED)

prop = new Trash at propSpawnPt,
    facing propSpawnPt.heading,
    with regionContainedIn None

terminate when ego intersects prop