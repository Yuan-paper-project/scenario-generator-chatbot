#################################
# Description                   #
#################################
description = "The ego vehicle is maintaining a constant speed; the adversarial car, comes from behind on the right, pulls out in front of the ego and blocks multiple lanes by driving extremely slowly, forcing the ego vehicle to change lanes."

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
param OPT_EGO_SPEED = Range(1, 6)
param OPT_EGO_OVERTAKE_DIST = Range(10, 20)  # Distance at which the ego vehicle starts overtaking

behavior EgoBehavior():
    do FollowLaneBehavior(globalParameters.OPT_EGO_SPEED) until withinDistanceToObjsInLane(self, globalParameters.OPT_EGO_OVERTAKE_DIST)
    do LaneChangeBehavior(egoLaneSec._laneToLeft, target_speed=globalParameters.OPT_EGO_SPEED)
    do FollowLaneBehavior(globalParameters.OPT_EGO_SPEED)

ego = new Car at egoSpawnPt,
    with regionContainedIn egoLaneSec,
    with blueprint EGO_MODEL,
    with behavior EgoBehavior()

#################################
# Adversarial                   #
#################################
from scenic.domains.driving.controllers import *

param OPT_EGO_SPEED = Range(1, 6) # Duplicated as it's used in calculations for ADV_SPEED_INITIAL/FINAL
param OPT_ADV_SPEED_INITIAL= globalParameters.OPT_EGO_SPEED * Range(13, 15)/10  # Adversarial vehicle starts faster than ego
param OPT_ADV_SPEED_FINAL = globalParameters.OPT_EGO_SPEED * Range(7, 9)/10  # Adversarial vehicle slows down
param OPT_ADV_ATTACK_DIST = Range(10, 15)  # Distance at which adversarial vehicle starts blocking

behavior FollowLeftEdgeBehavior(target_speed = 10, trajectory = None):
    """
    Follows the right edge of the given trajectory if a right lane exists,
    otherwise follows the left edge if a left lane exists.
    Raises an error if neither exists.
    """

    assert trajectory is not None
    assert isinstance(trajectory, list)

    distanceToEndpoint = 5  # meters

    has_left = all(hasattr(traj, 'leftEdge') and traj.leftEdge is not None for traj in trajectory)

    if has_left:
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

behavior AdversarialBehavior():
    do FollowLaneBehavior(globalParameters.OPT_ADV_SPEED_INITIAL) until distance from self to ego < globalParameters.OPT_ADV_ATTACK_DIST
    do FollowLaneBehavior(globalParameters.OPT_ADV_SPEED_INITIAL) until distance from self to ego >= globalParameters.OPT_ADV_ATTACK_DIST
    do FollowLeftEdgeBehavior(target_speed=globalParameters.OPT_ADV_SPEED_FINAL, trajectory=[rightLaneSec])


behavior FollowDynamicLeftEdgeBehavior(target_speed = 10):
    """
    Dynamically follows the left edge of the current lane, adapting to lane changes.
    """

    past_steer_angle = 0  # Initialize past steering angle

    while True:

        _lon_controller, _lat_controller = simulation().getLaneFollowingControllers(self)

        current_speed = self.speed if self.speed is not None else 0
        speed_error = target_speed - current_speed

        throttle = _lon_controller.run_step(speed_error)

        if self.lane is not None and hasattr(self.lane, 'leftEdge') and self.lane.leftEdge is not None:
            trajectory_edge = self.lane.leftEdge
            cte = trajectory_edge.signedDistanceTo(self.position)
            current_steer_angle = _lat_controller.run_step(cte)
        else:
            current_steer_angle = 0  # Default steering angle if no left edge is available

        take RegulatedControlAction(throttle, current_steer_angle, past_steer_angle)
        past_steer_angle = current_steer_angle

AdvAgent = new Car at AdvSpawnPt,
    with heading AdvSpawnPt.heading,
    with regionContainedIn rightLaneSec,
    with behavior AdversarialBehavior()

#################################
# Spatial Relation              #
#################################
param OPT_ADV_START_DIST = Range(5, 10) * -1

laneSecsWithRightLeftLane = []
for lane in network.lanes:
    for laneSec in lane.sections:
        if laneSec.isForward and laneSec._laneToLeft is not None and laneSec._laneToLeft.isForward and laneSec._laneToRight is not None and laneSec._laneToRight.isForward:
            laneSecsWithRightLeftLane.append(laneSec)

egoLaneSec = Uniform(*laneSecsWithRightLeftLane)
egoSpawnPt = new OrientedPoint in egoLaneSec.centerline

rightLaneSec = egoLaneSec._laneToRight
adjLanePt = rightLaneSec.centerline.project(egoSpawnPt.position)

AdvSpawnPt = new OrientedPoint following roadDirection from adjLanePt for globalParameters.OPT_ADV_START_DIST

#################################
# Requirements and Restrictions #
#################################
require distance to intersection >= 100  # Ensure the ego vehicle is far from the intersection
terminate when distance from ego to AdvAgent > 50