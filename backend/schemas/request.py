from datetime import datetime
from typing import List

from pydantic import BaseModel, Field


class BestTimeRequest(BaseModel):
    from_lat: float
    from_lng: float
    to_lat: float
    to_lng: float
    arrival_time: datetime
    search_window_minutes: int = Field(default=60, ge=15, le=360)
    interval_minutes: int = Field(default=15, ge=5, le=60)
    mapbox_route_junctions: List[str]
