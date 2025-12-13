#################################
# Description                   #
#################################
description = "The ego commences an unprotected left turn at an intersection while yielding to an oncoming car when the adversarial car, coming from the right, blocks multiple lanes by driving extremely slowly in between lanes, forcing the ego vehicle to drive slowly behind the adversarial vehicle."

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
param OPT_EGO_SPEED = Range(3, 5)
param OPT_EGO_YIELD_DIST = Range(8, 10) # Distance to adv at which ego must decide

behavior EgoBehavior():
    initialDir = egoSpawnPt.heading
    try:
        do FollowTrajectoryBehavior(trajectory=egoTrajectory, target_speed=globalParameters.OPT_EGO_SPEED)
    interrupt when (self.distanceToClosest(Car) < globalParameters.OPT_EGO_YIELD_DIST):
            take SetThrottleAction(0)
            take SetBrakeAction(1)
    terminate

ego = new Car at egoSpawnPt,
    with regionContainedIn None,
    with blueprint EGO_MODEL,
    with behavior EgoBehavior()

#################################
# Adversarial                   #
#################################
param OPT_ADV_SPEED= Range(1, 2)  # Oncoming car starts slow

behavior FollowEdgeBehavior(target_speed = 10, trajectory = None):
    """
    Follows the right edge of the given trajectory if a right lane exists,
    otherwise follows the left edge if a left lane exists.
    Raises an error if neither exists.
    """

    assert trajectory is not None
    assert isinstance(trajectory, list)

    distanceToEndpoint = 5 # meters

    has_right = all(hasattr(traj, 'rightEdge') and traj.rightEdge is not None for traj in trajectory)
    has_left = all(hasattr(traj, 'leftEdge') and traj.leftEdge is not None for traj in trajectory)

    if has_right:
        traj_edge = [traj.rightEdge for traj in trajectory]
    elif has_left:
        traj_edge = [traj.leftEdge for traj in trajectory]
    else:
        raise Exception("Neither rightEdge nor leftEdge exists for the given trajectory.")

    trajectory_edge = concatenateCenterlines(traj_edge)

    _lon_controller, _lat_controller = simulation().getLaneFollowingControllers(self)
    past_steer_angle = 0

    end_point = trajectory_edge[-1]

    while True:
        if (distance from self to end_point) < distanceToEndpoint:
            break

        current_speed = self.speed if self.speed is not None else 0

        cte = trajectory_edge.signedDistanceTo(self.position)
        speed_error = target_speed - current_speed

        throttle = _lon_controller.run_step(speed_error)

        current_steer_angle = _lat_controller.run_step(cte)

        take RegulatedControlAction(throttle, current_steer_angle, past_steer_angle)
        past_steer_angle = current_steer_angle

AdvAgent = new Car at advSpawnPt,
    with heading advSpawnPt.heading,
    with regionContainedIn None,
    with behavior FollowEdgeBehavior(trajectory=advTrajectory, target_speed=globalParameters.OPT_ADV_SPEED)

#################################
# Spatial Relation              #
#################################
param OPT_ADV_START_DIST = Range(5, 10)   # How far away the adv car starts

intersection = Uniform(*filter(lambda i: i.is4Way and (i.isSignalized == False), network.intersections))
egoManeuver = Uniform(*filter(lambda m: m.type is ManeuverType.LEFT_TURN, intersection.maneuvers))
egoTrajectory = [egoManeuver.startLane, egoManeuver.connectingLane, egoManeuver.endLane]
egoTrajectoryLine = egoManeuver.startLane.centerline + egoManeuver.connectingLane.centerline + egoManeuver.endLane.centerline
egoInitLane = egoManeuver.startLane
egoSpawnPt = new OrientedPoint in egoInitLane.centerline

advManeuver = Uniform(*filter(lambda m: m.type is ManeuverType.STRAIGHT, egoManeuver.conflictingManeuvers))
advTrajectory = [advManeuver.startLane, advManeuver.connectingLane, advManeuver.endLane]
advInitLane = advManeuver.startLane

advSpawnPt = new OrientedPoint following advInitLane.orientation from advInitLane.centerline.end for -globalParameters.OPT_ADV_START_DIST

advDir = advSpawnPt.heading
egoDir = egoSpawnPt.heading

#################################
# Requirements and Restrictions #
#################################
CONST_RIGHT_DEG = - 90 deg
CONST_TOL_DEG = 20 deg
CONST_MIN_RIGHT_DEG = CONST_RIGHT_DEG - CONST_TOL_DEG
CONST_MAX_RIGHT_DEG = CONST_RIGHT_DEG + CONST_TOL_DEG

require 50 <= (distance from egoSpawnPt to intersection) <= 60
require CONST_MIN_RIGHT_DEG < (egoDir - advDir) < CONST_MAX_RIGHT_DEG