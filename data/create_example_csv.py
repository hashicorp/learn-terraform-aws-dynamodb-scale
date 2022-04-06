#/usr/bin/python3

# Simple script to generate random environmental data

import csv
import random
import time
import uuid

def gen_uuids(count):
    for i in range(count):
        yield uuid.uuid4()

def random_geoLocation():
    locations = {"TX": ["Austin", "San Antonio"], "CA": ["Berkely", "Las Angeles", "San Diego"] , "VT": ["Burlington", "St. Albans"]}

    state = random.choice(list(locations))

    loc = {
        "planet": "Earth",
        "country": "US",
        "state": state,
        "city": random.choice(locations[state])
    }

    return "{planet}-{country}-{state}-{city}".format(**loc)

def random_time():
    return int(time.time()) - random.randint(100,10000)

def random_tempC():
    return round(random.random() * 120, 2)

def random_humidityPct():
    return random.randint(0,100)

def random_pressurePa():
    return random.randint(100000,105000)

def random_expiry(startEpochS):
    return random.choice((0,0,0,startEpochS + random.randint(60,600)))

with open('example_environments.csv', 'w') as csvfile:
    fields = ['userId', 'deviceId', 'eventId', 'geoLocation', 'epochS', 'expiry', 'tempC', 'humidityPct', 'pressurePa']
    envwriter = csv.writer(csvfile)

    envwriter.writerow(fields)

    for userId in gen_uuids(4):
        for deviceId in gen_uuids(2):

            geoLocation = random_geoLocation()

            for eventId in gen_uuids(10):
                epochS = random_time()
                expiry = random_expiry(epochS)
                tempC = random_tempC()
                humidityPct = random_humidityPct()
                pressurePa = random_pressurePa()

                envwriter.writerow([userId, deviceId, eventId, geoLocation, epochS, expiry, tempC, humidityPct, pressurePa])
