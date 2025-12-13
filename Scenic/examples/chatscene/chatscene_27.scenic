#################################
# Description                   #
#################################
description = "The ego vehicle is turning right; the adversarial vehicle enters the intersection from the left side, swerving to the right suddenly."

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
param OPT_BRAKE_DISTANCE = Range(5, 8)
param OPT_EGO_SPEED = Range (1, 5)

behavior WaitBehavior():
    while True:
        wait

behavior EgoBehavior():
    try:
        do FollowTrajectoryBehavior(trajectory=egoTrajectory, target_speed=globalParameters.OPT_EGO_SPEED)
    interrupt when (withinDistanceToObjsInLane(ego, globalParameters.OPT_BRAKE_DISTANCE)):
        take SetThrottleAction(0)  # Ensure no acceleration during braking
        take SetBrakeAction(1)  # Brake to avoid collision
    terminate

ego = new Car at egoSpawnPt,
    with regionContainedIn None,
    with blueprint EGO_MODEL,
    with behavior EgoBehavior()

#################################
# Adversarial                   #
#################################
param OPT_ADV_SPEED = globalParameters.OPT_EGO_SPEED * Uniform(1.1,1.2,1.3)

behavior FollowLineBehavior(line, target_speed=10):
    assert line is not None
    assert isinstance(line, PolylineRegion)

    distanceToEndpoint = 5  # meters
    end_point = line[-1]  # Last point of the PolylineRegion

    _lon_controller, _lat_controller = simulation().getLaneFollowingControllers(self)
    past_steer_angle = 0

    while (distance from self to end_point) > distanceToEndpoint:

        current_speed = self.speed if self.speed is not None else 0

        cte = line.signedDistanceTo(self.position)
        speed_error = target_speed - current_speed

        throttle = _lon_controller.run_step(speed_error)

        current_steer_angle = _lat_controller.run_step(cte)

        take RegulatedControlAction(throttle, current_steer_angle, past_steer_angle)
        past_steer_angle = current_steer_angle
   
behavior AdvBehavior(line, target_speed=10):
    do FollowLineBehavior(line=line, target_speed=target_speed)

    do FollowLaneBehavior(target_speed=target_speed)

AdvAgent = new Car at advSpawnPt,
    with heading advSpawnPt.heading,
    with regionContainedIn None,
    with behavior AdvBehavior(line=advTrajectoryLine, target_speed=globalParameters.OPT_ADV_SPEED)

#################################
# Spatial Relation              #
#################################
intersection = Uniform(*filter(lambda i: i.is4Way and i.isSignalized, network.intersections))

egoManeuver = Uniform(*filter(lambda m: m.type is ManeuverType.RIGHT_TURN, intersection.maneuvers))
egoTrajectory = [egoManeuver.startLane, egoManeuver.connectingLane, egoManeuver.endLane]
egoInitLane = egoManeuver.startLane
egoSpawnPt = new OrientedPoint in egoInitLane.centerline

advManeuver = Uniform(*filter(lambda m: m.type is ManeuverType.STRAIGHT, egoManeuver.conflictingManeuvers))
advTrajectory = [advManeuver.startLane, advManeuver.connectingLane, advManeuver.endLane]
advTrajectoryLine = advManeuver.startLane.centerline + advManeuver.connectingLane.rightEdge + advManeuver.endLane.centerline
advInitLane = advManeuver.startLane
advSpawnPt = new OrientedPoint in advInitLane.centerline

egoDir = egoSpawnPt.heading
advDir = advSpawnPt.heading

#################################
# Requirements and Restrictions #
#################################
CONST_RIGHT_DEG = 90 deg
CONST_TOL_DEG = 20 deg
CONST_MIN_RIGHT_DEG = CONST_RIGHT_DEG - CONST_TOL_DEG
CONST_MAX_RIGHT_DEG = CONST_RIGHT_DEG + CONST_TOL_DEG

monitor TrafficLights():
    freezeTrafficLights()
    while True:
        if withinDistanceToTrafficLight(ego, 100):
            setClosestTrafficLightStatus(ego, "green")
        if withinDistanceToTrafficLight(AdvAgent, 100):
            setClosestTrafficLightStatus(AdvAgent, "red")
        wait

require monitor TrafficLights()
require 30 <= (distance from egoSpawnPt to intersection) <= 40
require CONST_MIN_RIGHT_DEG < (egoDir - advDir) < CONST_MAX_RIGHT_DEG
require 10 <= (distance from advSpawnPt to intersection) <= 20