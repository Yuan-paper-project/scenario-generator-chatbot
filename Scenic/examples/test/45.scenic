description = "Vehicle is going straight in a rural area, in daylight, under clear weather conditions, on a dry road with a posted speed limit of 55 mph or more, and then loses control due to catastrophic component failure at a non-junction and runs off the road. Failure of tires, brakes, power train, steering system, and wheels contributed to about 95 percent of these crashes, with tires alone accounting for 62 percent of vehicle failure crashes"
Town = 'Town05'
param map = localPath(f'../../assets/maps/CARLA/{Town}.xodr')
param carla_map = Town
model scenic.simulators.carla.model
EGO_MODEL = "vehicle.lincoln.mkz_2017"
min_straight_road_length = 70
suitableLaneSections = []
for lane in network.lanes:
    for laneSec in lane.sections:
        if laneSec.isForward:
            if laneSec.centerline.length >= min_straight_road_length:
                suitableLaneSections.append(laneSec)
egoLaneSec = Uniform(*suitableLaneSections)

egoSpawnPt = new OrientedPoint in egoLaneSec.centerline

egoTrajectoryLine = egoLaneSec.centerline

param OPT_EGO_SPEED = Range(25, 30) # Adjusted for 55 mph or more (approx 24.58 m/s)
param FAILURE_DISTANCE = Range(50, 100)
param STEER_FAILURE_ANGLE = Uniform(20, -20)
param FAILURE_THROTTLE = Range(0.3, 0.6)
behavior WaitBehavior():
    while True:
        wait
behavior LossOfControlBehavior():
    # Car has lost control due to a catastrophic failure. Steering is locked to a random angle,
    # and a constant throttle is applied, leading the car to veer off the road.
    while True:
        take SetSteerAction(globalParameters.STEER_FAILURE_ANGLE)
        take SetThrottleAction(globalParameters.FAILURE_THROTTLE)
        take SetBrakeAction(0) # Ensure no braking during loss of control
        wait # Wait for the next simulation step to apply actions

behavior EgoBehavior():
    # Store the initial position of the ego car to calculate the distance traveled
    initial_pos = self.position

    # Phase 1: Travel straight along the lane at a specified speed
    # This phase continues until the car has traveled the 'FAILURE_DISTANCE'
    do FollowLaneBehavior(globalParameters.OPT_EGO_SPEED) until (distance from self to initial_pos) >= globalParameters.FAILURE_DISTANCE

    # Phase 2: Catastrophic component failure and loss of control
    # Once the failure distance is reached, the car switches to the LossOfControlBehavior,
    # simulating a component failure that causes it to lose steering control and run off the road.
    do LossOfControlBehavior()

ego = new Car at egoSpawnPt,
    with regionContainedIn None,
    with blueprint EGO_MODEL,
    with behavior EgoBehavior()
# Pedestrian-related parameters, behavior, and agent creation have been removed
# as the new scenario description does not include a pedestrian.




require len(suitableLaneSections) > 0
