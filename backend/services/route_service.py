import math


def route_distance_km(from_lat: float, from_lng: float, to_lat: float, to_lng: float) -> float:
    r = 6371.0
    d_lat = math.radians(to_lat - from_lat)
    d_lng = math.radians(to_lng - from_lng)
    a = (
        math.sin(d_lat / 2) ** 2
        + math.cos(math.radians(from_lat))
        * math.cos(math.radians(to_lat))
        * math.sin(d_lng / 2) ** 2
    )
    c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))
    return r * c


def traffic_level_from_jam(jam_factor: float) -> str:
    if jam_factor < 3.5:
        return "FREE"
    if jam_factor < 6.0:
        return "LIGHT"
    if jam_factor < 8.0:
        return "MODERATE"
    return "HEAVY"
