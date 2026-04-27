/// In-memory path for web-only mock GPS (set when [NavigationRoute] is loaded).
class WebPreviewState {
  WebPreviewState._();

  static List<List<double>>? activeRoutePolylineWgs;
  static int streamTick = 0;

  static void setActivePolyline(List<List<double>>? coords) {
    activeRoutePolylineWgs = coords;
    streamTick = 0;
  }
}
