#################################
# Description                   #
#################################
description = "The ego vehicle is turning left at an intersection; the adversarial motorcyclist on the right front pretends to cross the road but brakes abruptly at the edge of the road, causing confusion."
#################################
# Header                        #
#################################
Town = 'Town05'
param map = localPath(f'../../assets/maps/CARLA/{Town}.xodr') 
param carla_map = Town
model scenic.simulators.carla.model
EGO_MODEL = "vehicle.lincoln.mkz_2017"

#################################
# Ego                           #
#################################
param OPT_EGO_SPEED = Range(1, 5)

behavior FollowTrajectoryThenTerminateBehavior(speed, trajectory):
    do FollowTrajectoryBehavior(target_speed=speed, trajectory=trajectory)
    terminate

ego = new Car at egoSpawnPt,
    with regionContainedIn None,
    with blueprint EGO_MODEL,
    with behavior FollowTrajectoryThenTerminateBehavior(globalParameters.OPT_EGO_SPEED, egoTrajectory)

#################################
# Adversarial                   #
#################################
param OPT_EGO_SPEED = Range(1, 5) # Duplicated as per rules
param OPT_ADV_SPEED = globalParameters.OPT_EGO_SPEED * Uniform(1.1,1.2,1.3,1.4) # Make sure the adversarial agent is faster than the ego

behavior StopAtEndOfLaneBehavior(speed, lane):
    do FollowLaneBehavior(speed) until (distance from self to lane.centerline.end) < 1
    take SetBrakeAction(1)  # Brake abruptly at the edge of the road

AdvAgent = new Motorcycle at projectPt,
    with heading advHeading,
    with regionContainedIn None,
    with behavior StopAtEndOfLaneBehavior(globalParameters.OPT_ADV_SPEED, advLane)

#################################
# Spatial Relation              #
#################################
param OPT_GEO_Y_DISTANCE = Range(20, 35)

intersection = Uniform(*filter(lambda i: i.is4Way or i.is3Way, network.intersections))
egoManeuver = Uniform(*filter(lambda m: m.type is ManeuverType.LEFT_TURN, intersection.maneuvers))
egoInitLane = egoManeuver.startLane
advLane = egoInitLane._laneToRight  # The lane to the right of the ego's initial lane
egoTrajectory = [egoInitLane, egoManeuver.connectingLane, egoManeuver.endLane]

egoSpawnPt = new OrientedPoint in egoInitLane.centerline

advLane = network.laneSectionAt(egoSpawnPt).laneToRight.lane

IntSpawnPt = new OrientedPoint following roadDirection from egoSpawnPt for globalParameters.OPT_GEO_Y_DISTANCE
projectPt = advLane.centerline.project(IntSpawnPt.position)
advHeading = advLane.orientation[projectPt]

#################################
# Requirements and Restrictions #
#################################
require network.laneSectionAt(egoSpawnPt) is not None
require network.laneSectionAt(egoSpawnPt).laneToRight is not None
require 40 <= (distance to intersection) <= 60