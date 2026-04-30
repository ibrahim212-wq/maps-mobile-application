from datetime import datetime
from typing import List

from pydantic import BaseModel


class BestTimeSuggestion(BaseModel):
    departure_time: datetime
    estimated_duration_minutes: int
    arrival_time: datetime
    traffic_level: str
    confidence_score: float
    is_recommended: bool
    reasoning: str


class BestTimeResponse(BaseModel):
    route_distance_km: float
    junctions_analyzed: int
    suggestions: List[BestTimeSuggestion]
    ai_status: str
