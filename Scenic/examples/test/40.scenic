description = "Ego vehicle is following an adversary vehicle. Adversary suddenly stops and then resumes moving forward."
param map = localPath('../../assets/maps/CARLA/Town05.xodr')
param carla_map = 'Town05'
model scenic.simulators.carla.model
MODEL = 'vehicle.mini.cooper_s_2021'


initLane = Uniform(*network.lanes)
egoSpawnPt = new OrientedPoint in initLane.centerline

BYPASS_DIST = [15, 10]
param EGO_SPEED = Range(2, 4)
param EGO_BRAKE = Range(0.5, 1.0)
behavior EgoBehaviour():
    try:
        do FollowLaneBehavior(target_speed=globalParameters.EGO_SPEED)
    interrupt when withinDistanceToAnyObjs(self, BYPASS_DIST[0]):
        take SetBrakeAction(globalParameters.EGO_BRAKE)
ego = new Car at egoSpawnPt,
    with blueprint MODEL,
    with behavior EgoBehaviour()
param ADV_SPEED = Range(3, 5)
param ADV_BRAKE = Range(0.5, 1.0)
ADV_INIT_TIME = Range(15,20)
ADV_STOP_TIME = Range(10,15)
ADV_INIT_DIST = Range(22, 25)

behavior BrakeBehavior(brake):
    take SetBrakeAction(brake)

behavior AdvBehavior():
    print("racheced init")
    do FollowLaneBehavior(target_speed=globalParameters.ADV_SPEED) for ADV_INIT_TIME seconds
    print("racheced to stop")
    do BrakeBehavior(globalParameters.ADV_BRAKE) for ADV_STOP_TIME seconds
    print("racheced resume")
    do FollowLaneBehavior(target_speed=globalParameters.ADV_SPEED)
adv = new Car following roadDirection from ego for ADV_INIT_DIST,
    with blueprint MODEL,
    with behavior AdvBehavior()

INIT_DIST = 50
TERM_DIST = 100
require (distance to intersection) > INIT_DIST
require (distance from adv to intersection) > INIT_DIST
require always (ego.laneSection._slowerLane is not None)
terminate when (distance to egoSpawnPt) > TERM_DIST