description = "Ego vehicle changes lanes at a high-speed urban non-junction, then encroaches into a same-direction vehicle."
param map = localPath('../../assets/maps/CARLA/Town04.xodr')
param carla_map = 'Town04'
model scenic.simulators.carla.model
MODEL = 'vehicle.lincoln.mkz_2017'
param weather = 'ClearNoon'

laneSecsWithLeftLane = []
for lane in network.lanes:
    for sec in lane.sections:
        if sec.isForward and sec._laneToLeft is not None and sec._laneToLeft.isForward:
            laneSecsWithLeftLane.append(sec)

egoLaneSec = Uniform(*laneSecsWithLeftLane)
egoSpawnPt = new OrientedPoint in egoLaneSec.centerline

advLaneSec = egoLaneSec._laneToLeft
refVec = advLaneSec.centerline.project(egoSpawnPt.position)
refPt = new OrientedPoint at refVec, facing egoSpawnPt.heading
advSpawnPt = new OrientedPoint ahead of refPt by Range(10, 20)

param EGO_SPEED = Range(15, 20)

behavior EgoBehavior(speed, target_lane_sec):
	do FollowLaneBehavior(target_speed=speed) for Range(1, 2) seconds
	do LaneChangeBehavior(laneSectionToSwitch=target_lane_sec, target_speed=speed)
	do FollowLaneBehavior(target_speed=speed)

ego = new Car at egoSpawnPt,
	with blueprint MODEL,
	with behavior EgoBehavior(globalParameters.EGO_SPEED, advLaneSec)

param ADV_SPEED = Range(15, 20)

behavior AdversaryBehavior(speed):
	do FollowLaneBehavior(target_speed=speed)

adversary = new Car at advSpawnPt,
	with blueprint MODEL,
	with behavior AdversaryBehavior(globalParameters.ADV_SPEED)

require 10 <= (distance from egoSpawnPt to advSpawnPt) <= 20
terminate when (distance from ego to egoSpawnPt) > 150
terminate after 20 seconds