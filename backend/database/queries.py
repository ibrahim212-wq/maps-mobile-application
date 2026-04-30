from typing import Iterable, List, TypedDict

from database.connection import get_connection


class HistoricalPatternRow(TypedDict):
    hour: int
    day_of_week: int
    avg_jam: float
    avg_speed: float
    sample_count: int


def fetch_historical_patterns(junction_ids: Iterable[str]) -> List[HistoricalPatternRow]:
    ids = list({j for j in junction_ids if j})
    if not ids:
        return []

    query = """
    SELECT
        hour,
        day_of_week,
        AVG(jam_factor) as avg_jam,
        AVG(current_speed) as avg_speed,
        COUNT(*) as sample_count
    FROM traffic_readings
    WHERE junction_id = ANY(%s)
    GROUP BY hour, day_of_week
    ORDER BY hour, day_of_week
    """

    with get_connection() as conn:
        with conn.cursor() as cur:
            cur.execute(query, (ids,))
            rows = cur.fetchall()

    out: List[HistoricalPatternRow] = []
    for row in rows:
        out.append(
            {
                "hour": int(row[0]),
                "day_of_week": int(row[1]),
                "avg_jam": float(row[2] or 0.0),
                "avg_speed": float(row[3] or 0.0),
                "sample_count": int(row[4] or 0),
            }
        )
    return out
