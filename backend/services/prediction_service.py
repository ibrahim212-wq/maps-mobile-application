from models.ai_predictor import MockPredictor
from schemas.request import BestTimeRequest
from schemas.response import BestTimeResponse


class PredictionService:
    def __init__(self) -> None:
        self._predictor = MockPredictor()

    def best_time(self, req: BestTimeRequest) -> BestTimeResponse:
        distance_km, junctions_analyzed, suggestions, ai_status = self._predictor.predict_best_times(req)
        return BestTimeResponse(
            route_distance_km=distance_km,
            junctions_analyzed=junctions_analyzed,
            suggestions=suggestions,
            ai_status=ai_status,
        )
