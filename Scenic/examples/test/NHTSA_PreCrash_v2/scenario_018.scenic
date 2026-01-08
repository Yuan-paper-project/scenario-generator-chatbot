description = "Vehicle performs an aggressive cut-in maneuver on another vehicle travelling in the same direction at 35 mph."
param map = localPath('../../assets/maps/CARLA/Town05.xodr')
param carla_map = 'Town05'
model scenic.simulators.carla.model
MODEL = 'vehicle.lincoln.mkz_2017'
param weather = 'ClearNoon'

laneSecsWithNeighbor = []
for lane in network.lanes:
    for section in lane.sections:
        if section._laneToLeft and section._laneToLeft.isForward == section.isForward:
            laneSecsWithNeighbor.append((section, section._laneToLeft))
        if section._laneToRight and section._laneToRight.isForward == section.isForward:
            laneSecsWithNeighbor.append((section, section._laneToRight))

selectedPair = Uniform(*laneSecsWithNeighbor)
egoLaneSec = selectedPair[0]
advLaneSec = selectedPair[1]

egoInitLane = egoLaneSec.lane
advInitLane = advLaneSec.lane

egoSpawnPt = new OrientedPoint in egoLaneSec.centerline
advSpawnPt = new OrientedPoint in advLaneSec.centerline

require 10 <= (distance from egoSpawnPt to advSpawnPt) <= 20
require advSpawnPt is ahead of egoSpawnPt

egoTrajectory = [egoInitLane, advInitLane]
advTrajectory = [advInitLane]

param OPT_EGO_SPEED = 15.65
param OPT_CUT_IN_SPEED = 20.0
param OPT_BRAKE_DISTANCE = 5

behavior EgoBehavior(target_speed, cut_speed, target_lane):
    try:
        do FollowLaneBehavior(target_speed=cut_speed) for 5 seconds
        do LaneChangeBehavior(laneSectionToSwitch=target_lane, target_speed=target_speed)
        do FollowLaneBehavior(target_speed=target_speed)
    interrupt when withinDistanceToAnyCars(self, globalParameters.OPT_BRAKE_DISTANCE):
        take SetThrottleAction(0)
        take SetBrakeAction(1)

ego = new Car at egoSpawnPt,
    with regionContainedIn egoLaneSec,
    with blueprint MODEL,
    with behavior EgoBehavior(globalParameters.OPT_EGO_SPEED, globalParameters.OPT_CUT_IN_SPEED, advLaneSec)

param ADV_SPEED = 15.65

behavior AdversaryBehavior(trajectory):
    do FollowTrajectoryBehavior(target_speed=globalParameters.ADV_SPEED, trajectory=trajectory)

adversary = new Car at advSpawnPt,
    with blueprint MODEL,
    with behavior AdversaryBehavior(advTrajectory)

require 10 <= (distance from egoSpawnPt to advSpawnPt) <= 20
require advSpawnPt is ahead of egoSpawnPt
terminate after 15 seconds