description = "Ego vehicle drifts into an adjacent vehicle while going straight in an urban area with a high speed limit."
param map = localPath('../../assets/maps/CARLA/Town04.xodr')
param carla_map = 'Town04'
model scenic.simulators.carla.model
MODEL = 'vehicle.lincoln.mkz_2017'
param weather = 'ClearNoon'

laneSecsWithAdj = []
for lane in network.lanes:
    for sec in lane.sections:
        if sec._laneToLeft and sec._laneToLeft.isForward == sec.isForward:
            laneSecsWithAdj.append((sec, sec._laneToLeft))
        elif sec._laneToRight and sec._laneToRight.isForward == sec.isForward:
            laneSecsWithAdj.append((sec, sec._laneToRight))

selected = Uniform(*laneSecsWithAdj)
egoSec = selected[0]
advSec = selected[1]

egoSpawnPt = new OrientedPoint in egoSec.centerline
advPos = advSec.centerline.project(egoSpawnPt.position)
advSpawnPt = new OrientedPoint at advPos, facing egoSpawnPt.heading

egoTrajectory = [egoSec.lane]
advTrajectory = [advSec.lane]

param EGO_SPEED = Range(15, 20)
param START_DRIFT_TIME = Range(2, 4)

behavior EgoBehavior(speed, traj, target_lane, drift_time):
	do FollowTrajectoryBehavior(target_speed=speed, trajectory=traj) for drift_time seconds
	do LaneChangeBehavior(laneSectionToSwitch=target_lane, target_speed=speed)
	do FollowLaneBehavior(target_speed=speed)

ego = new Car at egoSpawnPt,
	with blueprint MODEL,
	with behavior EgoBehavior(globalParameters.EGO_SPEED, egoTrajectory, advSec, globalParameters.START_DRIFT_TIME)

param ADV_SPEED = globalParameters.EGO_SPEED

behavior AdvBehavior(speed, traj):
	do FollowTrajectoryBehavior(target_speed=speed, trajectory=traj)
	do FollowLaneBehavior(target_speed=speed)

AdvAgent = new Car at advSpawnPt,
	with blueprint MODEL,
	with behavior AdvBehavior(globalParameters.ADV_SPEED, advTrajectory)

monitor TrafficLights():
    freezeTrafficLights()
    while True:
        if withinDistanceToTrafficLight(ego, 100):
            setClosestTrafficLightStatus(ego, "green")
        if withinDistanceToTrafficLight(AdvAgent, 100):
            setClosestTrafficLightStatus(AdvAgent, "green")
        wait

require monitor TrafficLights()
require distance from egoSpawnPt to intersection > 50
terminate after 10 seconds