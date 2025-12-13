param map = localPath('../../assets/maps/CARLA/Town05.xodr')
param carla_map = 'Town05'
model scenic.simulators.carla.model
MODEL = 'vehicle.mini.cooper_s_2021'
param EGO_SPEED = Range(3, 5)
param EGO_BRAKE = Range(0.5, 1.0)
SAFE_DIST = 15
behavior EgoBehavior():
    try:
        do FollowLaneBehavior(target_speed=globalParameters.EGO_SPEED)
    interrupt when withinDistanceToAnyObjs(self,SAFE_DIST):
        take SetBrakeAction(globalParameters.EGO_BRAKE)
behavior BrakeBehavior(brake):
    take SetBrakeAction(brake)
param ADV_SPEED = Range(3, 5)
param ADV_BRAKE = Range(0.5, 1.0)
ADV_INIT_TIME = Range(15,20)
ADV_STOP_TIME = Range(10,15)
behavior AdvBehavior():
    print("racheced init")
    do FollowLaneBehavior(target_speed=globalParameters.ADV_SPEED) for ADV_INIT_TIME seconds
    print("racheced to stop")
    do BrakeBehavior(globalParameters.ADV_BRAKE) for ADV_STOP_TIME seconds
    print("racheced resume")
    do FollowLaneBehavior(target_speed=globalParameters.ADV_SPEED)
initLane = Uniform(*network.lanes)
egoSpawnPt = new OrientedPoint in initLane.centerline
ego = new Car at egoSpawnPt,
    with blueprint MODEL,
    with behavior EgoBehavior()
ADV_INIT_DIST = Range(22, 25)
adv = new Car following roadDirection from ego for ADV_INIT_DIST,
    with blueprint MODEL,
    with behavior AdvBehavior()
INIT_DIST = 80
TERM_DIST = 100
require (distance to intersection) > INIT_DIST
require (distance from adv to intersection) > INIT_DIST
terminate when (distance to egoSpawnPt) > TERM_DIST