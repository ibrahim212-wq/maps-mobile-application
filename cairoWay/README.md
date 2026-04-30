# RouteMind — AI-Powered Traffic Prediction App

## Project Overview
- Smart traffic prediction app for Cairo & Giza
- Predicts future traffic, not just current conditions
- Built for graduation project

## AI Architecture
GCN → LSTM → Prophet → Decision Layer

### GCN Layer
- Processes spatial relationships between 460 junctions
- Each junction "sees" its neighbors' conditions
- Graph structure from OpenStreetMap

### LSTM Layer
- Learns temporal patterns from historical data
- Uses spatial embeddings from GCN as input
- Trained on 15 days of real Cairo traffic data

### Prophet Layer
- Handles seasonal decomposition
- Daily and weekly patterns
- Cairo-specific patterns (Friday different from Sunday)

### Decision Layer
- Fuses all predictions
- Outputs: predicted_speed, jam_factor, confidence per junction

## Data Collection
- Source: TomTom Traffic Flow API
- Coverage: 460 junctions (350 Cairo + 110 Giza)
- Interval: Every 20 min (daytime), 40 min (nighttime)
- Storage: PostgreSQL on GCP Cloud SQL
- Status: [ACTIVE - collecting data]

## Infrastructure
- GCP Compute Engine: cairo-traffic-collector
- GCP Cloud SQL: PostgreSQL (cairo_traffic database)
- Flutter App: RouteMind
- Backend: FastAPI (in development)

## Features Status

### ✅ Implemented
- Real Mapbox map with traffic overlay
- Real GPS location
- Real Mapbox search (Arabic + English)
- Turn-by-turn navigation with TTS
- Dark/Light mode (premium design)
- Saved places (Hive)
- Incident reporting
- Google Maps-style search ranking with Arabic normalization
- Category-based icon mapping for search results
- Distance display in search results
- Text highlighting for matched search terms
- Stale-result prevention in autocomplete
- Result caching for performance
- Best Time to Leave (AI-powered, mock service in Flutter)

### 🔄 In Development
- Predictive Rerouting
- AI Route Confidence Score

### 📋 Planned
- Explainable AI Routes
- Cairo Driving Modes
- Community Reports + AI Validation
- Traffic Heatmap

## API Endpoints (Backend)
- POST /api/v1/best-time
- POST /api/v1/predict
- POST /api/v1/route
- GET /api/v1/traffic/live
- POST /api/v1/incidents/report

## Project Structure

```
lib/
├── api/                          # API client layer
├── core/
│   ├── constants/                # App-wide constants (API keys, defaults)
│   ├── routing/                  # Go Router navigation configuration
│   ├── theme/                    # Theme (light/dark), colors, typography
│   └── utils/                    # Utility functions
├── features/
│   ├── alerts/                   # Traffic incident alerts
│   │   └── presentation/screens/
│   ├── home/                     # Main map screen
│   │   ├── presentation/
│   │   │   ├── providers/        # Map state providers
│   │   │   ├── screens/          # Home screen
│   │   │   └── widgets/          # MapView, overlay widgets
│   ├── insights/                 # Traffic insights/analytics
│   │   └── presentation/screens/
│   ├── navigation/               # Turn-by-turn navigation
│   │   └── presentation/screens/
│   ├── onboarding/               # First-run onboarding
│   │   └── presentation/screens/
│   ├── profile/                  # User profile, settings
│   │   ├── presentation/
│   │   │   ├── providers/
│   │   │   └── screens/
│   ├── routing/                  # Route options, route selection
│   │   ├── presentation/
│   │   │   ├── providers/
│   │   │   └── screens/
│   └── search/                   # Place search with autocomplete
│       └── presentation/screens/
├── shared/
│   ├── models/                   # Data models (Place, RouteOption, Trip, etc.)
│   ├── services/                 # Shared services (Directions, Places, Location, Storage)
│   └── widgets/                  # Reusable widgets
```

## Environment Variables
- `MAPBOX_ACCESS_TOKEN` — Required for Mapbox Maps SDK and Search Box API
- `GOOGLE_MAPS_API_KEY` — Used as fallback for Google Places autocomplete
- `TOMTOM_API_KEY` — TomTom Traffic Flow API for live traffic data
- `AI_BASE_URL` — Backend API base URL (default: https://api.routemind.ai/v1)

## How to Run

### Prerequisites
- Flutter 3.19+ SDK
- Android Studio / Xcode (for mobile builds)
- Mapbox Access Token

### Setup
1. Clone the repository
2. Copy `.env.example` to `.env` (if provided) or create `.env` with required keys:
   ```
   MAPBOX_ACCESS_TOKEN=your_mapbox_token_here
   GOOGLE_MAPS_API_KEY=your_google_key_here
   TOMTOM_API_KEY=your_tomtom_key_here
   AI_BASE_URL=https://api.routemind.ai/v1
   ```
3. Install dependencies:
   ```bash
   flutter pub get
   ```
4. Run the app:
   ```bash
   flutter run
   ```

### Build
- **Android APK**: `flutter build apk`
- **iOS IPA**: `flutter build ios` (requires macOS + Xcode)

## Important Notes
- AI service shows "initializing" state until model is ready
- All predictions use real historical patterns when AI is connected
- Arabic + Franco search supported with normalization (ة=ه, أ=ا, ى=ي, diacritics stripped)
- Cairo local landmarks supported via transliteration aliases (zayed → Sheikh Zayed, etc.)
- Search results are ranked by: text relevance, distance, Cairo/Giza bias, saved/recent boost, POI type
- Navigation uses Mapbox Search Box API with Google Places fallback for richer Egyptian POIs
- Session tokens are renewed after each place selection for proper Mapbox billing
- Search results are cached in-memory (60 entries) for performance
- Stale search results are discarded using epoch guard

## Tech Stack
- **Framework**: Flutter 3.19+
- **State Management**: Riverpod
- **Map Provider**: Mapbox Maps Flutter plugin
- **Routing**: Go Router
- **Storage**: Hive (local), PostgreSQL (backend)
- **Search**: Mapbox Search Box API + Google Places fallback
- **Directions**: Mapbox Directions API
- **AI Backend**: FastAPI (planned)

