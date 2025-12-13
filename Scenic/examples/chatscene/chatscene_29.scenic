#################################
# Description                   #
#################################
description = "The ego vehicle is turning right; the adversarial car (positioned behind) suddenly accelerates and then decelerates."

#################################
# Header                        #
#################################
Town = 'Town05'
param map = localPath(f'../../assets/maps/CARLA/{Town}.xodr')
param carla_map = Town
model scenic.simulators.carla.model
from scenic.domains.driving.controllers import *

EGO_MODEL = "vehicle.lincoln.mkz_2017"

#################################
# Ego                           #
#################################
param OPT_EGO_SPEED = Range(5, 8)
param OPT_BRAKE_DIST = Range(5, 10)

behavior WaitBehavior():
    while True:
        wait

behavior EgoBehavior():
    try:
        do FollowTrajectoryBehavior(trajectory=egoTrajectory, target_speed=globalParameters.OPT_EGO_SPEED)
    interrupt when (withinDistanceToObjsInLane(self, globalParameters.OPT_BRAKE_DIST)):
        take SetThrottleAction(0)
        take SetBrakeAction(1)
    terminate

ego = new Car at egoSpawnPt,
    with regionContainedIn egoLaneSec,
    with blueprint EGO_MODEL,
    with behavior EgoBehavior()

#################################
# Adversarial                   #
#################################
param OPT_ADV_SPEED = Range(5, 8)
param OPT_ADV_TRIGGER_SECONDS = Range(1, 3)
param OPT_DECELLERATE_DISTANCE = Range(5, 7)
param OPT_ADV_BRAKE = Range(5, 10)/10
param OPT_ADV_THROTTLE = Range(5, 10)/10

behavior AccelerateBehavior(throttle, trajectory):
    """
    Accelerates the vehicle with a fixed throttle value while maintaining lateral stability
    using a PIDLateralController. The vehicle follows the given trajectory and adjusts its
    steering angle to minimize cross-track error.
    """

    lateral_controller = PIDLateralController(K_P=0.3, K_D=0.2, K_I=0, dt=0.1)

    past_steer_angle = 0  # Initialize past steering angle

    while True:
        cte = trajectory.signedDistanceTo(self.position)  # Distance to the trajectory centerline

        steering_angle = lateral_controller.run_step(cte)

        take RegulatedControlAction(throttle, steering_angle, past_steer_angle)

        past_steer_angle = steering_angle

behavior AdvBehavior():
    do FollowLaneBehavior(target_speed=globalParameters.OPT_ADV_SPEED) for globalParameters.OPT_ADV_TRIGGER_SECONDS seconds
    do AccelerateBehavior(throttle=globalParameters.OPT_ADV_THROTTLE, trajectory=egoTrajectoryLine) until distance from self to ego < globalParameters.OPT_DECELLERATE_DISTANCE
    do AccelerateBehavior(throttle=-globalParameters.OPT_ADV_BRAKE, trajectory=egoTrajectoryLine) until distance from self to ego >= globalParameters.OPT_DECELLERATE_DISTANCE
    do FollowLaneBehavior(target_speed=globalParameters.OPT_ADV_SPEED)

AdvAgent = new Car at AdvSpawnPt,
    with regionContainedIn advLaneSec,
    with blueprint EGO_MODEL,
    with behavior AdvBehavior()

#################################
# Spatial Relation              #
#################################
param OPT_BEHIND_DIST = Range(10, 15)

intersection = Uniform(*filter(lambda i: i.is4Way, network.intersections))
egoManeuver = Uniform(*filter(lambda m: m.type is ManeuverType.RIGHT_TURN , intersection.maneuvers))
egoTrajectory = [egoManeuver.startLane, egoManeuver.connectingLane, egoManeuver.endLane]
egoTrajectoryLine = egoManeuver.startLane.centerline + egoManeuver.connectingLane.centerline + egoManeuver.endLane.centerline
egoLaneSec = egoManeuver.startLane
advLaneSec = egoLaneSec
egoSpawnPt = new OrientedPoint in egoLaneSec.centerline

AdvSpawnPt = new OrientedPoint following roadDirection from egoSpawnPt for -globalParameters.OPT_BEHIND_DIST

#################################
# Requirements and Restrictions #
#################################
require 30 <= (distance from egoSpawnPt to intersection) <= 40