description = "Ego vehicle drives straight in an urban area and performs an evasive action to avoid an obstacle."
param map = localPath('../../../assets/maps/CARLA/Town05.xodr')
param carla_map = 'Town05'
model scenic.simulators.carla.model
MODEL = 'vehicle.lincoln.mkz_2017'
param weather = 'ClearSunset'

egoLane = Uniform(*network.lanes)
egoSpawnPt = new OrientedPoint on egoLane.centerline
obstacleSpawnPt = new OrientedPoint following egoLane.orientation from egoSpawnPt for Range(15, 25)

param EGO_SPEED = Range(10, 15)
param EVASIVE_THRESHOLD = Range(15, 20)

behavior EgoBehavior(speed, threshold):
    do FollowLaneBehavior(target_speed=speed) until withinDistanceToObjsInLane(self, threshold)
    if self.laneSection._laneToLeft:
        do LaneChangeBehavior(laneSectionToSwitch=self.laneSection._laneToLeft, target_speed=speed)
    elif self.laneSection._laneToRight:
        do LaneChangeBehavior(laneSectionToSwitch=self.laneSection._laneToRight, target_speed=speed)
    else:
        take SetBrakeAction(1.0)
    do FollowLaneBehavior(target_speed=speed)

ego = new Car at egoSpawnPt,
    with blueprint MODEL,
    with rolename 'hero',  
    with behavior EgoBehavior(globalParameters.EGO_SPEED, globalParameters.EVASIVE_THRESHOLD)

obstacle = new Trash at obstacleSpawnPt,
    facing obstacleSpawnPt.heading,
    with regionContainedIn None

monitor TrafficLights():
    freezeTrafficLights()
    while True:
        if withinDistanceToTrafficLight(ego, 100):
            setClosestTrafficLightStatus(ego, "green")
        wait

require monitor TrafficLights()

terminate when (distance from ego to obstacle) > 30
terminate after 40 seconds