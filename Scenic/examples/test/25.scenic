description = "Ego vehicle is following an adversary vehicle. Adversary suddenly stops and then resumes moving forward."
param map = localPath('../../assets/maps/CARLA/Town05.xodr')
param carla_map = 'Town05'
model scenic.simulators.carla.model
MODEL = 'vehicle.mini.cooper_s_2021'

behavior BrakeBehavior(brake):
    take SetBrakeAction(brake)
param ADV_SPEED = Range(3, 5)
param ADV_BRAKE = Range(0.5, 1.0)
ADV_INIT_TIME = Range(15,20)
ADV_STOP_TIME = Range(10,15)
param EGO_SPEED = Range(7, 10)

behavior AdvBehavior():
    print("racheced init")
    do FollowLaneBehavior(target_speed=globalParameters.ADV_SPEED) for ADV_INIT_TIME seconds
    print("racheced to stop")
    do BrakeBehavior(globalParameters.ADV_BRAKE) for ADV_STOP_TIME seconds
    print("racheced resume")
    do FollowLaneBehavior(target_speed=globalParameters.ADV_SPEED)

behavior EgoBehavior(trajectory):
    do FollowTrajectoryBehavior(target_speed=globalParameters.EGO_SPEED, trajectory=trajectory)

initLane = Uniform(*network.lanes)
egoSpawnPt = new OrientedPoint in initLane.centerline
ego = new Car at egoSpawnPt,
    with blueprint MODEL,
    with behavior EgoBehavior(trajectory=initLane.centerline)
ADV_INIT_DIST = Range(22, 25)
adv = new Car following roadDirection from ego for ADV_INIT_DIST,
    with blueprint MODEL,
    with behavior AdvBehavior()
INIT_DIST = 80
TERM_DIST = 100
require (distance to intersection) > INIT_DIST
require (distance from adv to intersection) > INIT_DIST
terminate when (distance to egoSpawnPt) > TERM_DIST

