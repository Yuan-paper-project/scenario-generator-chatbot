#################################
# Description                   #
#################################

description = "Ego Vehicle waits at 4-way intersection while adversary vehicle in adjacent lane passes before performing a lane change to bypass a stationary vehicle."

#################################
# Header                        #
#################################

param map = localPath('../../assets/maps/CARLA/Town05.xodr')
param carla_map = 'Town05'
model scenic.simulators.carla.model

MODEL = 'vehicle.mini.cooper_s_2021'

#################################
# Ego                           #
#################################

param EGO_SPEED = Range(7, 10)
param EGO_BRAKE = Range(0.5, 1.0)
BYPASS_DIST = 8

behavior EgoBehavior():
	while (distance to adversary) < BYPASS_DIST:
		take SetBrakeAction(globalParameters.EGO_BRAKE)
	rightLaneSec = self.laneSection.laneToRight
	do LaneChangeBehavior(
			laneSectionToSwitch=rightLaneSec,
			target_speed=globalParameters.EGO_SPEED)
	do FollowLaneBehavior(target_speed=globalParameters.EGO_SPEED)

param EGO_INIT_DIST = Range(10, 15)

ego = new Car behind stationary by globalParameters.EGO_INIT_DIST,
	with blueprint MODEL,
	with behavior EgoBehavior()

#################################
# Adversarial                   #
#################################

ADV_SPEED = 10

behavior AdversaryBehavior(trajectory):
	do FollowTrajectoryBehavior(target_speed=ADV_SPEED, trajectory=trajectory)

adversary = new Car at advSpawnPt,
	with blueprint MODEL,
	with behavior AdversaryBehavior(advTrajectory)

#################################
# Spatial Relation              #
#################################

intersection = Uniform(*filter(lambda i: i.is4Way, network.intersections))

statInitLane = Uniform(*filter(lambda lane:
	all([sec._laneToRight is not None for sec in lane.sections]),
	intersection.incomingLanes))
statSpawnPt = new OrientedPoint in statInitLane.centerline

advInitLane = statInitLane.sectionAt(statSpawnPt).laneToRight.lane
advManeuver = Uniform(*filter(lambda m: m.type is ManeuverType.STRAIGHT, advInitLane.maneuvers))
advTrajectory = [advInitLane, advManeuver.connectingLane, advManeuver.endLane]
advSpawnPt = new OrientedPoint in advInitLane.centerline

#################################
# Requirements and Restrictions #
#################################
ADV_INIT_DIST = [15, 20]

STAT_INIT_DIST = [0, 5]
TERM_DIST = 70

stationary = new Car at statSpawnPt,
	with blueprint MODEL

require STAT_INIT_DIST[0] <= (distance from stationary to intersection) <= STAT_INIT_DIST[1]
require ADV_INIT_DIST[0] <= (distance from adversary to intersection) <= ADV_INIT_DIST[1]
terminate when (distance to statSpawnPt) > TERM_DIST