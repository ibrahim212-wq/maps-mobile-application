from datetime import timedelta
from typing import Dict, List, Tuple

from database.queries import fetch_historical_patterns
from schemas.request import BestTimeRequest
from schemas.response import BestTimeSuggestion
from services.route_service import route_distance_km, traffic_level_from_jam


class MockPredictor:
    """Historical-pattern predictor using real DB aggregates (non-random)."""

    def _patterns_map(self, junction_ids: List[str]) -> Dict[Tuple[int, int], dict]:
        rows = fetch_historical_patterns(junction_ids)
        patterns: Dict[Tuple[int, int], dict] = {}
        for row in rows:
            patterns[(row["hour"], row["day_of_week"])] = row
        return patterns

    def predict_best_times(self, req: BestTimeRequest) -> tuple[float, int, List[BestTimeSuggestion], str]:
        patterns = self._patterns_map(req.mapbox_route_junctions)
        distance_km = route_distance_km(req.from_lat, req.from_lng, req.to_lat, req.to_lng)

        suggestions: List[BestTimeSuggestion] = []
        start = req.arrival_time - timedelta(minutes=req.search_window_minutes)
        steps = max(1, req.search_window_minutes // req.interval_minutes)

        for i in range(steps + 1):
            departure = start + timedelta(minutes=i * req.interval_minutes)
            key = (departure.hour, departure.weekday())
            pattern = patterns.get(key)

            if pattern:
                avg_jam = float(pattern["avg_jam"])
                avg_speed = max(10.0, float(pattern["avg_speed"]))
                sample_count = int(pattern["sample_count"])
            else:
                avg_jam = 6.5
                avg_speed = 28.0
                sample_count = 0

            duration_minutes = max(5, int(round((distance_km / avg_speed) * 60)))
            predicted_arrival = departure + timedelta(minutes=duration_minutes)
            traffic_level = traffic_level_from_jam(avg_jam)

            confidence = 0.45
            if sample_count > 0:
                confidence = min(0.96, 0.55 + min(sample_count, 500) / 1000)

            suggestions.append(
                BestTimeSuggestion(
                    departure_time=departure,
                    estimated_duration_minutes=duration_minutes,
                    arrival_time=predicted_arrival,
                    traffic_level=traffic_level,
                    confidence_score=round(confidence, 2),
                    is_recommended=False,
                    reasoning=(
                        f"Based on historical pattern at hour {departure.hour}, "
                        f"day {departure.weekday()}, jam_factor={avg_jam:.2f}, "
                        f"avg_speed={avg_speed:.1f} km/h."
                    ),
                )
            )

        if suggestions:
            best_idx = min(
                range(len(suggestions)),
                key=lambda idx: (
                    suggestions[idx].estimated_duration_minutes,
                    abs((suggestions[idx].arrival_time - req.arrival_time).total_seconds()),
                    -suggestions[idx].confidence_score,
                ),
            )
            suggestions[best_idx].is_recommended = True

        ai_status = "ready" if patterns else "initializing"
        return round(distance_km, 2), len(req.mapbox_route_junctions), suggestions, ai_status
