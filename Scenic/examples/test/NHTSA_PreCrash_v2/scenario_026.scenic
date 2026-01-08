description = "Ego vehicle follows a lead vehicle in a rural area, which suddenly decelerates."
param map = localPath('../../assets/maps/CARLA/Town07.xodr')
param carla_map = 'Town07'
model scenic.simulators.carla.model
MODEL = 'vehicle.lincoln.mkz_2017'
param weather = 'ClearNoon'

param leadDistance = Range(15, 25)

egoLane = Uniform(*network.lanes)
egoSpawnPt = new OrientedPoint in egoLane.centerline
leadSpawnPt = new OrientedPoint following egoLane.orientation from egoSpawnPt for globalParameters.leadDistance

param EGO_SPEED = Range(10, 15)
param SAFETY_DISTANCE = 15

behavior EgoBehavior(speed, safety_dist):
    do DriveAvoidingCollisions(target_speed=speed, avoidance_threshold=safety_dist)

ego = new Car at egoSpawnPt,
    with blueprint MODEL,
    with behavior EgoBehavior(globalParameters.EGO_SPEED, globalParameters.SAFETY_DISTANCE)

param LEAD_SPEED = Range(10, 15)
param LEAD_BRAKE = Range(0.7, 1.0)
param LEAD_DRIVE_DURATION = Range(3, 5)

behavior LeadBehavior():
    do FollowLaneBehavior(target_speed=globalParameters.LEAD_SPEED) for globalParameters.LEAD_DRIVE_DURATION seconds
    while self.speed > 0:
        take SetBrakeAction(globalParameters.LEAD_BRAKE)

adversary = new Car at leadSpawnPt,
    with blueprint MODEL,
    with behavior LeadBehavior()

param TERM_DIST = 100

require 15 <= (distance from egoSpawnPt to leadSpawnPt) <= 25
terminate when (distance to egoSpawnPt) > globalParameters.TERM_DIST