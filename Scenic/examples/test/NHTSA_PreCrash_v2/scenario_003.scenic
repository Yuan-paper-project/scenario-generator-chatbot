description = "Ego vehicle loses control on a wet rural road at high speed and runs off-road."
param map = localPath('../../../assets/maps/CARLA/Town05.xodr')
param carla_map = 'Town05'
model scenic.simulators.carla.model
MODEL = 'vehicle.lincoln.mkz_2017'
param weather = 'WetNoon'

egoInitLane = Uniform(*network.lanes)
egoSpawnPt = new OrientedPoint in egoInitLane.centerline
egoTrajectory = [egoInitLane]

param OPT_EGO_SPEED = Range(20, 25)
param OPT_LOSS_CONTROL_TIME = Range(3, 5)
param OPT_STEER_VALUE = Range(0.6, 0.8)

behavior EgoBehavior(speed, duration, steer_val):
    try:
        do FollowLaneBehavior(target_speed=speed) for duration seconds
    interrupt when True:
        while True:
            take SetSteerAction(steer_val), SetThrottleAction(0.6)

ego = new Car at egoSpawnPt,
    with blueprint MODEL,
    with behavior EgoBehavior(
        globalParameters.OPT_EGO_SPEED,
        globalParameters.OPT_LOSS_CONTROL_TIME,
        globalParameters.OPT_STEER_VALUE
    )

INIT_DIST = 50
SAFE_DIST = 10

require (distance to intersection) > INIT_DIST
terminate when (ego not in network.roads) and (distance to egoSpawnPt > SAFE_DIST)