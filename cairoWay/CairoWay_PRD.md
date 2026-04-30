# CairoWay — Product Requirements Document (PRD)

## Smart Traffic Prediction App for Cairo & Giza

**Version:** 1.0
**Date:** April 24, 2026
**Author:** Ibrahim Elnaggar

---

## 1. Product Overview

### 1.1 Vision
CairoWay is an AI-powered traffic prediction and navigation app for Cairo and Giza. Unlike Google Maps which shows current traffic, CairoWay predicts future traffic using a GCN+LSTM+Prophet AI pipeline trained on real Cairo traffic data, helping users find the best time to leave and the fastest route.

### 1.2 One-Line Description
"Google Maps tells you traffic now. CairoWay tells you traffic when you arrive."

### 1.3 Target Users
- Daily commuters in Cairo & Giza
- Ride-sharing / taxi drivers
- Anyone who drives regularly in Greater Cairo

### 1.4 Platform
- Android (primary)
- iOS (secondary)
- Built with Flutter

---

## 2. Tech Stack

### 2.1 Frontend
- **Framework:** Flutter (Dart)
- **Maps:** Mapbox Maps SDK for Flutter
- **Navigation:** Mapbox Navigation SDK
- **State Management:** Riverpod or Provider
- **Local Storage:** SharedPreferences + Hive

### 2.2 Backend
- **API Framework:** FastAPI (Python)
- **AI Model:** GCN → LSTM → Prophet → Decision Layer
- **Database:** PostgreSQL (Cloud SQL on GCP)
- **Routing Engine:** OSRM (self-hosted on GCP)
- **Hosting:** GCP Compute Engine
- **Push Notifications:** Firebase Cloud Messaging
- **Analytics:** Firebase Analytics
- **Crash Reporting:** Sentry (free tier)

### 2.3 External APIs
- **TomTom Traffic Flow API** — real-time traffic speed data
- **Mapbox Maps API** — map display and search
- **Mapbox Navigation SDK** — turn-by-turn directions
- **OpenStreetMap** — traffic signal locations

---

## 3. AI Architecture

### 3.1 Pipeline
```
Real-time Traffic Data (TomTom)
        │
        ▼
┌──────────────────┐
│   GCN Layer      │  ← Spatial relationships between junctions
│   (Graph Conv)   │  ← "If junction A is congested, junction B nearby will be too"
└────────┬─────────┘
         │
    ┌────┴─────┐
    │          │
    ▼          ▼
┌─────────┐  ┌──────────┐
│  LSTM   │  │ Prophet  │
│(Temporal│  │(Seasonal)│  ← "Rush hour pattern every Sunday-Thursday"
│ trends) │  │          │
└────┬────┘  └─────┬────┘
     │             │
     └──────┬──────┘
            │
            ▼
┌──────────────────┐
│ Decision Layer   │  ← Fuses LSTM + Prophet predictions
│ (Feature Fusion) │  ← Outputs: predicted speed per junction
└────────┬─────────┘
         │
         ▼
   Predicted traffic
   for every junction
```

### 3.2 Training Data
- **Source:** TomTom Traffic Flow API
- **Coverage:** 460 junctions across Cairo (350) and Giza (110)
- **Duration:** 15 days continuous collection
- **Interval:** Every 20 minutes (daytime), every 40 minutes (nighttime)
- **Total expected readings:** ~600,000

### 3.3 Features Collected
- current_speed (km/h)
- free_flow_speed (km/h)
- current_travel_time (seconds)
- free_flow_travel_time (seconds)
- confidence (0-1)
- road_closure (boolean)
- congestion_ratio (derived)
- speed_reduction (derived)
- delay_seconds (derived)
- jam_factor (0-10, derived)
- congestion_level (FREE/LIGHT/MODERATE/HEAVY/GRIDLOCK)
- hour, minute, day_of_week, is_weekend, is_friday (temporal)

---

## 4. App Screens & Features

### 4.1 Screen Flow
```
Splash Screen
    │
    ▼
Onboarding (first time only)
    │ Step 1: Set Home location
    │ Step 2: Set Work location
    │ Step 3: Set usual commute time
    │
    ▼
Home Screen (Map View)
    │
    ├── Search bar (top)
    │     └── Search Results
    │           └── Route Options Screen
    │                 └── Navigation Screen
    │                       └── Post-Trip Feedback
    │
    ├── Traffic Heatmap toggle
    ├── Incident Report (bottom sheet)
    ├── AI Smart Card (proactive suggestion)
    │
    └── Bottom Nav:
          ├── Home (Map)
          ├── Insights (AI recommendations)
          ├── Alerts (notifications)
          └── Profile (settings + saved places)
```

---

### 4.2 Screen Details

#### Screen 1: Splash Screen
- App logo + loading animation
- 2 seconds max

#### Screen 2: Onboarding (3 steps — first launch only)
**Step 1:** "Where is your home?"
- Map with pin — user places on map or searches
- Save as favorite

**Step 2:** "Where is your work?"
- Same as above
- Save as favorite

**Step 3:** "When do you usually commute?"
- Time picker: 6-7 AM / 7-8 AM / 8-9 AM / 9-10 AM / Custom
- Days: Sunday-Thursday / Custom

#### Screen 3: Home Screen (Main Map)
**Layout:**
- Full-screen Mapbox map
- User location centered (blue dot)
- Traffic overlay (color-coded roads: green/yellow/orange/red)
- Traffic signal locations (from OSM) shown as small icons
- Search bar at top
- AI Smart Card at bottom (collapsible)

**AI Smart Card (proactive — no user action needed):**
```
┌─────────────────────────────────┐
│ 🤖 Good morning!               │
│                                 │
│ 🏠 → 🏢 Work                   │
│ Right now: 35 min               │
│ Best time to leave: 7:15 AM     │
│ (28 min — save 7 min)           │
│                                 │
│ [Navigate Now]  [Set Reminder]  │
└─────────────────────────────────┘
```

**Traffic Heatmap:**
- Toggle button on map
- Shows real-time congestion overlay
- Color scale: Green (free) → Yellow (light) → Orange (moderate) → Red (heavy) → Dark Red (gridlock)

#### Screen 4: Search
**Trigger:** User taps search bar

**Layout:**
- Search input with autocomplete (Mapbox Search)
- Recent searches
- Saved places (Home, Work, starred)
- "From" field (defaults to current location)
- "To" field

#### Screen 5: Route Options
**Trigger:** User selects destination

**Layout:**
- Map showing all routes
- Bottom sheet with route cards (scrollable)
- Time picker: "Leave Now" / "Schedule" / "AI Recommend"

**Route Cards:**
```
┌─────────────────────────────────┐
│ 🤖 AI Pick                     │
│ via Ring Road → Salah Salem     │
│                                 │
│ ⏱ 28 min    📊 Low traffic     │
│                                 │
│ "This route will stay clear     │
│  for the next hour"             │
└─────────────────────────────────┘

┌─────────────────────────────────┐
│ 🟡 Alternative                  │
│ via 26 July Corridor            │
│                                 │
│ ⏱ 35 min    📊 Medium traffic  │
│                                 │
│ "Building up — expect 45 min    │
│  if you leave in 20 min"        │
└─────────────────────────────────┘

┌─────────────────────────────────┐
│ 🔴 Avoid                        │
│ via Downtown                    │
│                                 │
│ ⏱ 52 min    📊 Heavy traffic   │
│                                 │
│ "Major congestion — not         │
│  recommended"                   │
└─────────────────────────────────┘
```

**AI Time Recommendation:**
```
┌─────────────────────────────────┐
│ ⚡ Best time to leave            │
│                                 │
│ 🟢 7:15 AM → Arrive 7:45       │
│    28 min (fastest today)       │
│                                 │
│ 🟡 7:45 AM → Arrive 8:30       │
│    45 min (rush hour starts)    │
│                                 │
│ 🔴 8:15 AM → Arrive 9:15       │
│    60 min (peak congestion)     │
│                                 │
│ Note: AI won't suggest          │
│ unreasonable times (e.g. 3 AM)  │
└─────────────────────────────────┘
```

#### Screen 6: Navigation (During Driving)
**Layout:**
- Full-screen map with route
- Turn-by-turn directions (Mapbox Navigation SDK)
- Voice guidance (Arabic + English)
- ETA updated in real-time using AI predictions
- Incident report button (floating)

**Dynamic Re-routing:**
```
┌─────────────────────────────────┐
│ ⚠️ New congestion ahead         │
│ 8 minute delay detected         │
│                                 │
│ Faster route available          │
│ Save 5 minutes via Ring Road    │
│                                 │
│ [Switch Route]  [Keep Current]  │
└─────────────────────────────────┘
```

**Calm Design:**
- Minimal UI during driving
- Large text for ETA and next turn
- Dark mode auto-activates at night
- Ultra-dark mode during navigation (reduce eye strain)

#### Screen 7: Post-Trip Feedback
**Trigger:** User arrives at destination

```
┌─────────────────────────────────┐
│ ✅ You've arrived!               │
│                                 │
│ Trip: 31 minutes                │
│ AI predicted: 28 minutes        │
│ Accuracy: 90%                   │
│                                 │
│ How was the route?              │
│ 😊 Great  😐 OK  😤 Bad        │
│                                 │
│ Report an issue? [Tap here]     │
└─────────────────────────────────┘
```

#### Screen 8: AI Insights
**Layout:**
- Daily commute summary
- Weekly pattern analysis
- Savings tracker ("You saved 2.5 hours this week")
- Best/worst times to travel

```
┌─────────────────────────────────┐
│ 📊 This Week                    │
│                                 │
│ Total trips: 12                 │
│ Time saved: 2.5 hours           │
│ AI accuracy: 87%                │
│                                 │
│ 🔥 Worst day: Sunday 8 AM      │
│ ✅ Best day: Tuesday 7:15 AM    │
│                                 │
│ 💡 Tip: Leave 15 min earlier    │
│ on Sundays to avoid 26 July     │
│ corridor congestion             │
└─────────────────────────────────┘
```

#### Screen 9: Alerts Settings
- Enable/disable smart alerts
- Set alert timing (15/30/60 min before commute)
- Set alert for specific routes
- Incident alerts for saved routes

#### Screen 10: Profile & Saved Places
- Saved locations (Home, Work, custom)
- Saved routes (frequent trips)
- App settings (language, units, dark mode)
- Voice guidance settings (Arabic/English)
- Privacy settings

#### Screen 11: Incident Report (Bottom Sheet)
**Trigger:** User taps report button on map or during navigation

**One-tap reporting:**
```
┌─────────────────────────────────┐
│ Report an incident              │
│                                 │
│ 🚧 Accident     🚗 Heavy Traffic│
│ 🚫 Road Closed  🚔 Police      │
│ 🚧 Construction  ⚠️ Hazard     │
│                                 │
│ [Optional: Add note]            │
│ [Submit]                        │
└─────────────────────────────────┘
```
- Auto-detects location
- One tap to submit
- Shows on map for other users
- Auto-expires after 2 hours

---

## 5. Feature Priority

### Must Have (v1.0)
1. Map display with traffic overlay
2. Search with autocomplete
3. Route options with AI predictions
4. Turn-by-turn navigation with voice
5. AI time recommendation
6. Saved places (Home, Work)
7. Traffic signal locations on map
8. Dark mode (auto)

### Should Have (v1.1)
1. Smart Alerts / Push notifications
2. Incident reporting
3. Post-trip feedback
4. AI Insights dashboard
5. Weekly pattern learning
6. Home screen widget

### Nice to Have (v2.0)
1. Arabic voice guidance
2. Multi-stop routing
3. EV charging station locations
4. Parking suggestions
5. Social features (share ETA)
6. Fuel price comparison

---

## 6. API Endpoints

### 6.1 Backend API (FastAPI)

```
POST /api/v1/predict
  Input: { junctions: [ids], time: "2026-04-24T08:00:00" }
  Output: { predictions: [{ junction_id, predicted_speed, predicted_jam }] }

POST /api/v1/route
  Input: { from: {lat, lng}, to: {lat, lng}, departure_time }
  Output: { routes: [{ path, duration, distance, ai_score, reason }] }

POST /api/v1/best-time
  Input: { from: {lat, lng}, to: {lat, lng}, date, earliest, latest }
  Output: { suggestions: [{ time, duration, traffic_level }] }

GET /api/v1/traffic/live
  Input: { bbox: {north, south, east, west} }
  Output: { junctions: [{ id, lat, lng, speed, jam_factor }] }

POST /api/v1/incidents/report
  Input: { lat, lng, type, note? }
  Output: { id, status }

GET /api/v1/incidents/nearby
  Input: { lat, lng, radius_km }
  Output: { incidents: [{ id, lat, lng, type, time, verified_count }] }

GET /api/v1/insights/weekly
  Input: { user_id }
  Output: { trips, time_saved, accuracy, tips }

POST /api/v1/feedback
  Input: { trip_id, rating, predicted_time, actual_time }
  Output: { status }
```

---

## 7. Data Flow

### 7.1 Real-time Flow (User requests a route)
```
User opens app
    │
    ▼
App sends current location → Backend
    │
    ▼
Backend fetches live traffic from TomTom (cached, 15 min)
    │
    ▼
AI Model predicts future traffic for requested time
    │
    ▼
OSRM calculates routes using AI-weighted edges
    │
    ▼
Backend returns ranked routes with AI explanations
    │
    ▼
App displays route options to user
```

### 7.2 Background Flow (Continuous)
```
Every 15 minutes:
TomTom API → Backend → Database → Model updates predictions

Every 24 hours:
Model retrains on new data (optional, for accuracy improvement)
```

---

## 8. Design Guidelines

### 8.1 Color Palette
- **Primary:** #1A73E8 (Blue — trust, navigation)
- **Secondary:** #00C853 (Green — clear traffic)
- **Warning:** #FF9800 (Orange — moderate traffic)
- **Danger:** #F44336 (Red — heavy traffic)
- **Background Light:** #FFFFFF
- **Background Dark:** #121212
- **Surface Dark:** #1E1E1E
- **Text Primary:** #212121
- **Text Secondary:** #757575

### 8.2 Typography
- **Font:** Cairo (Arabic support) + Inter (English)
- **Headings:** Bold, 18-24sp
- **Body:** Regular, 14-16sp
- **Captions:** Light, 12sp

### 8.3 Design Principles
1. **Zero friction** — show useful info before user asks
2. **Calm navigation** — minimal UI during driving
3. **AI transparency** — always explain WHY a route is recommended
4. **One-tap actions** — incident report, route switch, feedback
5. **Predictive, not reactive** — always show what WILL happen

### 8.4 Dark Mode
- Auto-switch based on time
- Ultra-dark during navigation
- OLED-optimized blacks

---

## 9. Non-Functional Requirements

### 9.1 Performance
- App cold start: < 3 seconds
- Route calculation: < 2 seconds
- Map load: < 1 second
- AI prediction: < 500ms

### 9.2 Offline Support
- Cached map tiles for last-used area
- Saved routes work offline
- Graceful degradation without internet

### 9.3 Battery
- Background location updates: every 30 seconds (during navigation only)
- No background GPS when app is closed
- Dark mode to save battery

### 9.4 Privacy
- Location data stays on device unless navigating
- No tracking when app is closed
- User can delete all data
- GDPR-compliant data handling

---

## 10. Monetization (Future)

### 10.1 Freemium Model
**Free:**
- Basic navigation
- 3 AI route predictions/day
- Traffic overlay

**Premium ($2.99/month):**
- Unlimited AI predictions
- Smart alerts
- Weekly insights
- Ad-free
- Priority routing

### 10.2 B2B Opportunities
- Fleet management API
- Delivery route optimization
- Insurance company partnerships (driving behavior data)

---

## 11. Success Metrics

### 11.1 KPIs
- Daily Active Users (DAU)
- AI prediction accuracy (target: > 80%)
- Average time saved per trip
- User retention (Day 7, Day 30)
- App store rating (target: 4.5+)
- Crash-free rate (target: 99.5%)

---

## 12. Timeline

### Phase 1: MVP (Weeks 1-4)
- Flutter app with Mapbox
- Basic map + search + navigation
- AI model integration
- Route options with predictions

### Phase 2: Enhancement (Weeks 5-8)
- Smart alerts
- Incident reporting
- Post-trip feedback
- AI insights dashboard

### Phase 3: Polish & Launch (Weeks 9-12)
- Performance optimization
- Beta testing
- App Store / Play Store submission
- Marketing materials

---

## 13. Cost Summary

### One-Time Costs
| Item | Cost (USD) | Cost (EGP) |
|------|-----------|------------|
| Google Play Store | $25 | 1,250 |
| Apple App Store | $99 | 4,950 |
| Data Collection (15 days) | $300 | 15,000 |
| Colab Pro (training) | $10 | 500 |
| Domain name | $12 | 600 |
| **Total** | **$446** | **22,300** |

### Monthly Costs — MVP (100 users)
| Item | Cost (USD) | Cost (EGP) |
|------|-----------|------------|
| GCP Instance | $24 | 1,200 |
| Cloud SQL | $10 | 500 |
| OSRM Instance | $7 | 350 |
| Cloud Storage | $3 | 150 |
| TomTom API | $12 | 600 |
| Mapbox | $0 | 0 |
| Firebase | $0 | 0 |
| Apple (annual/12) | $8 | 400 |
| **Total** | **$64** | **3,200** |

### Monthly Costs — Growth (1,000 users)
| Item | Cost (USD) | Cost (EGP) |
|------|-----------|------------|
| GCP Instance | $48 | 2,400 |
| Cloud SQL | $10 | 500 |
| OSRM Instance | $7 | 350 |
| Cloud Storage | $5 | 250 |
| TomTom API | $85 | 4,250 |
| Mapbox Navigation | $50 | 2,500 |
| Mapbox Maps | $12 | 600 |
| Cloud Run | $5 | 250 |
| Apple (annual/12) | $8 | 400 |
| **Total** | **$230** | **11,500** |
