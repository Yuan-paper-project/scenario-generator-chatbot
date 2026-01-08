description = "Vehicle backs up from a driveway/alley in an urban area and collides with another vehicle."
param map = localPath('../../../assets/maps/CARLA/Town05.xodr')
param carla_map = 'Town05'
model scenic.simulators.carla.model
MODEL = 'vehicle.lincoln.mkz_2017'
param weather = 'ClearNoon'

intersection = Uniform(*filter(lambda i: i.is3Way, network.intersections))
egoManeuver = Uniform(*filter(lambda m: m.type is ManeuverType.STRAIGHT, intersection.maneuvers))
advManeuver = Uniform(*egoManeuver.conflictingManeuvers)
egoInitLane = egoManeuver.startLane
advInitLane = advManeuver.startLane
advPt = advInitLane.centerline.points[-1]
advSpawnPt = new OrientedPoint at advPt, facing (advInitLane.orientation[advPt] + 3.1415)
egoSpawnPt = new OrientedPoint following egoInitLane.orientation from advSpawnPt.position for Range(-25, -15)

param OPT_BACKUP_THROTTLE = Range(0.2, 0.4)

behavior EgoBackingUpBehavior(throttle_val):
    while True:
        take SetReverseAction(True), SetThrottleAction(throttle_val)

ego = new Car at egoSpawnPt,
    with blueprint MODEL,
    with rolename 'hero',  
    with behavior EgoBackingUpBehavior(globalParameters.OPT_BACKUP_THROTTLE)

param OPT_ADV_SPEED = Range(7, 12)

behavior AdversaryBehavior(target_speed):
    do FollowLaneBehavior(target_speed=target_speed, is_oppositeTraffic=True)

adversary = new Car at advSpawnPt,
    with blueprint MODEL,
    with behavior AdversaryBehavior(globalParameters.OPT_ADV_SPEED)

monitor TrafficLights():
    freezeTrafficLights()
    while True:
        wait

require monitor TrafficLights()
terminate when ego intersects adversary