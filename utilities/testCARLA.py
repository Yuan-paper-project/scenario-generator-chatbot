import carla
client = carla.Client('localhost', 2000)
world = client.get_world()
blueprint_library = world.get_blueprint_library()
vehicles = blueprint_library.filter('vehicle.*')
for vehicle in vehicles:
    print(vehicle.id)

# vehicle.audi.a2
# vehicle.nissan.micra
# vehicle.audi.tt
# vehicle.mercedes.coupe_2020
# vehicle.bmw.grandtourer
# vehicle.harley-davidson.low_rider
# vehicle.ford.ambulance
# vehicle.micro.microlino
# vehicle.carlamotors.firetruck
# vehicle.carlamotors.carlacola
# vehicle.carlamotors.european_hgv
# vehicle.ford.mustang
# vehicle.chevrolet.impala
# vehicle.lincoln.mkz_2020
# vehicle.citroen.c3
# vehicle.dodge.charger_police
# vehicle.nissan.patrol
# vehicle.jeep.wrangler_rubicon
# vehicle.mini.cooper_s
# vehicle.mercedes.coupe
# vehicle.dodge.charger_2020
# vehicle.ford.crown
# vehicle.seat.leon
# vehicle.toyota.prius
# vehicle.yamaha.yzf
# vehicle.kawasaki.ninja
# vehicle.bh.crossbike
# vehicle.mitsubishi.fusorosa
# vehicle.tesla.model3
# vehicle.gazelle.omafiets
# vehicle.tesla.cybertruck
# vehicle.diamondback.century
# vehicle.mercedes.sprinter
# vehicle.audi.etron
# vehicle.volkswagen.t2
# vehicle.lincoln.mkz_2017
# vehicle.dodge.charger_police_2020
# vehicle.vespa.zx125
# vehicle.mini.cooper_s_2021
# vehicle.nissan.patrol_2021
# vehicle.volkswagen.t2_2021