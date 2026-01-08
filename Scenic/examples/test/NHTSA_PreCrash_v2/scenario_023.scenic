description = "Ego vehicle performs a lane change or passing maneuver in an urban area at a non-junction with a 55 mph speed limit, closing in on a lead vehicle."
param map = localPath('../../assets/maps/CARLA/Town05.xodr')
param carla_map = 'Town05'
model scenic.simulators.carla.model
MODEL = 'vehicle.lincoln.mkz_2017'
param weather = 'ClearNoon'

param LEAD_DIST = Range(20, 30)

egoLane = Uniform(*network.lanes)
egoSpawnPt = new OrientedPoint in egoLane.centerline
leadSpawnPt = new OrientedPoint following roadDirection from egoSpawnPt for globalParameters.LEAD_DIST

param OPT_EGO_SPEED = Range(18, 22)
param OPT_OVERTAKE_DIST = Range(15, 20)
param OPT_BRAKE_DIST = 5

behavior EgoBehavior(speed, overtake_dist, brake_dist, target_lane):
    try:
        do FollowLaneBehavior(target_speed=speed) until withinDistanceToObjsInLane(self, overtake_dist)
        if target_lane:
            do LaneChangeBehavior(laneSectionToSwitch=target_lane, target_speed=speed)
        do FollowLaneBehavior(target_speed=speed)
    interrupt when withinDistanceToObjsInLane(self, brake_dist):
        take SetBrakeAction(1)
        terminate

egoLaneSec = egoLane.sections[0]
targetLaneSec = egoLaneSec._laneToLeft if egoLaneSec._laneToLeft else egoLaneSec._laneToRight

ego = new Car at egoSpawnPt,
    with regionContainedIn None,
    with blueprint MODEL,
    with behavior EgoBehavior(globalParameters.OPT_EGO_SPEED, globalParameters.OPT_OVERTAKE_DIST, globalParameters.OPT_BRAKE_DIST, targetLaneSec)

param OPT_LEADING_SPEED = globalParameters.OPT_EGO_SPEED - 5

LeadingAgent = new Car at leadSpawnPt,
    with regionContainedIn None,
    with behavior FollowLaneBehavior(target_speed=globalParameters.OPT_LEADING_SPEED)

TERM_DIST = 100

require 20 <= (distance from egoSpawnPt to leadSpawnPt) <= 30
terminate when (distance to egoSpawnPt) > TERM_DIST