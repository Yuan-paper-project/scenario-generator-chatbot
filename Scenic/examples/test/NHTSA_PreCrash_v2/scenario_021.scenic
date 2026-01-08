description = "Ego vehicle attempts to pass another vehicle in a rural area, encroaching into oncoming traffic."
param map = localPath('../../assets/maps/CARLA/Town07.xodr')
param carla_map = 'Town07'
model scenic.simulators.carla.model
MODEL = 'vehicle.lincoln.mkz_2017'
param weather = 'ClearNoon'

param EGO_TO_LEAD_DIST = Range(15, 25)
param EGO_TO_ONCOMING_DIST = Range(60, 100)

opposingRoads = list(filter(lambda r: r.forwardLanes is not None and r.backwardLanes is not None, network.roads))
targetRoad = Uniform(*opposingRoads)

egoLane = Uniform(*targetRoad.forwardLanes.lanes)
opposingLane = Uniform(*targetRoad.backwardLanes.lanes)

egoSpawnPt = new OrientedPoint on egoLane.centerline

leadAdvSpawnPt = new OrientedPoint following roadDirection from egoSpawnPt for globalParameters.EGO_TO_LEAD_DIST

opposingBasePt = opposingLane.centerline.project(egoSpawnPt.position)
tempOP = new OrientedPoint following roadDirection from opposingBasePt for globalParameters.EGO_TO_ONCOMING_DIST
oncomingAdvSpawnPt = new OrientedPoint at tempOP.position, facing (egoSpawnPt.heading + 3.14159)

param OPT_EGO_SPEED = Range(8, 12)
param OPT_EGO_SAFETY_DISTANCE = 5
param OPT_OVERTAKE_DISTANCE = 15

behavior EgoBehavior(speed, overtake_dist, safety_dist):
    try:
        do FollowLaneBehavior(target_speed=speed) until (distance from self to LeadingAgent) < overtake_dist
        
        opposing_sec = opposingLane.sections[0]
        do LaneChangeBehavior(laneSectionToSwitch=opposing_sec, is_oppositeTraffic=True, target_speed=speed)
        
        do FollowLaneBehavior(target_speed=speed, is_oppositeTraffic=True) until (distance from self to LeadingAgent) > overtake_dist
        
        original_sec = egoLane.sections[0]
        do LaneChangeBehavior(laneSectionToSwitch=original_sec, target_speed=speed)
        
        do FollowLaneBehavior(target_speed=speed)
        
    interrupt when withinDistanceToObjsInLane(self, safety_dist):
        take SetBrakeAction(1.0)

ego = new Car at egoSpawnPt,
    with blueprint MODEL,
    with behavior EgoBehavior(
        globalParameters.OPT_EGO_SPEED,
        globalParameters.OPT_OVERTAKE_DISTANCE,
        globalParameters.OPT_EGO_SAFETY_DISTANCE
    )

param OPT_LEAD_SPEED = Range(4, 6)
param OPT_ONCOMING_SPEED = Range(8, 12)

LeadingAgent = new Car at leadAdvSpawnPt,
    with blueprint MODEL,
    with behavior FollowLaneBehavior(target_speed=globalParameters.OPT_LEAD_SPEED)

OncomingAgent = new Car at oncomingAdvSpawnPt,
    with blueprint MODEL,
    with behavior FollowLaneBehavior(target_speed=globalParameters.OPT_ONCOMING_SPEED, is_oppositeTraffic=True)

param OPT_LEADING_SPEED = Range(5, 7)
param OPT_ONCOMING_SPEED = Range(8, 12)

LeadingAgent = new Car at leadAdvSpawnPt,
    with behavior FollowLaneBehavior(target_speed=globalParameters.OPT_LEADING_SPEED)

OncomingAgent = new Car at oncomingAdvSpawnPt,
    with behavior FollowLaneBehavior(target_speed=globalParameters.OPT_ONCOMING_SPEED)

terminate when ego in opposingLane