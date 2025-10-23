import 'package:flutter_dotenv/flutter_dotenv.dart';

class Env {
  static String get nominatimBaseUrl =>
      dotenv.maybeGet('NOMINATIM_BASE_URL') ??
      'https://nominatim.openstreetmap.org';

  static String get mapTileUrl =>
      dotenv.maybeGet('MAP_TILE_URL') ??
      'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png';

  static String get mapAttribution =>
      dotenv.maybeGet('MAP_ATTRIBUTION') ?? '© OpenStreetMap contributors';

  static bool get debugSeedEnabled =>
      dotenv.maybeGet('DEBUG_SEED', fallback: '0') == '1';
}
