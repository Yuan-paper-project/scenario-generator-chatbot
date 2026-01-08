description = "Vehicle loses control on wet road and runs off the road."
param map = localPath('../../../assets/maps/CARLA/Town05.xodr')
param carla_map = 'Town05'
model scenic.simulators.carla.model
MODEL = 'vehicle.lincoln.mkz_2017'
param weather = 'WetNoon'

egoInitLane = Uniform(*network.lanes)
egoSpawnPt = new OrientedPoint in egoInitLane.centerline
egoTrajectory = [egoInitLane]

param OPT_EGO_SPEED = Range(12, 18)
param OPT_SWERVE_STEER = Range(0.5, 0.9)
param OPT_SWERVE_START = Range(2, 5)

behavior EgoBehavior(speed, swerve_steer, swerve_start):
    try:
        do FollowLaneBehavior(target_speed=speed) for swerve_start seconds
        while True:
            take SetSteerAction(swerve_steer)
            take SetThrottleAction(0.7)
    interrupt when not (self in network.roadRegion):
        take SetThrottleAction(0)
        take SetBrakeAction(1)
        terminate

ego = new Car at egoSpawnPt,
    with blueprint MODEL,
    with rolename 'hero',  
    with behavior EgoBehavior(
        globalParameters.OPT_EGO_SPEED,
        globalParameters.OPT_SWERVE_STEER,
        globalParameters.OPT_SWERVE_START
    )

require (distance from egoSpawnPt to intersection) > 30
terminate after 15 seconds