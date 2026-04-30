from fastapi import APIRouter, HTTPException

from schemas.request import BestTimeRequest
from schemas.response import BestTimeResponse
from services.prediction_service import PredictionService

router = APIRouter()
service = PredictionService()


@router.post("/best-time", response_model=BestTimeResponse)
def best_time(payload: BestTimeRequest) -> BestTimeResponse:
    if not payload.mapbox_route_junctions:
        raise HTTPException(status_code=400, detail="mapbox_route_junctions must not be empty")
    return service.best_time(payload)
