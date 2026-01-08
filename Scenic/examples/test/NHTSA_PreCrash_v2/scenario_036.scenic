description = "Ego vehicle collides with an object while driving straight in a rural area at night with a high speed limit."
param map = localPath('../../../assets/maps/CARLA/Town05.xodr')
param carla_map = 'Town05'  
model scenic.simulators.carla.model
MODEL = 'vehicle.lincoln.mkz_2017'
param weather = 'ClearNoon'

egoLane = Uniform(*network.lanes)
egoSpawnPt = new OrientedPoint in egoLane.centerline
propSpawnPt = new OrientedPoint following egoLane.orientation from egoSpawnPt for Range(30, 50)

param OPT_EGO_SPEED = Range(22, 28)

behavior EgoBehavior(speed):
    do FollowLaneBehavior(target_speed=speed)

ego = new Car at egoSpawnPt,
    with blueprint MODEL,
    with behavior EgoBehavior(globalParameters.OPT_EGO_SPEED)

prop = new Trash at propSpawnPt,
    with regionContainedIn None

require network.laneSectionAt(egoSpawnPt) is not None
require 30 <= (distance from egoSpawnPt to propSpawnPt) <= 50
terminate when ego intersects prop