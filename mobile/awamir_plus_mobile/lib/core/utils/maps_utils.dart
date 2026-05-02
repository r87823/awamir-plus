class GeoPoint {
  const GeoPoint({required this.latitude, required this.longitude});

  final double latitude;
  final double longitude;
}

GeoPoint? extractGoogleMapsCoordinates(String url) {
  final trimmed = url.trim();
  if (trimmed.isEmpty) return null;

  final patterns = [
    RegExp(r'[?&]q=(-?\d+(?:\.\d+)?),\s*(-?\d+(?:\.\d+)?)'),
    RegExp(r'@(-?\d+(?:\.\d+)?),\s*(-?\d+(?:\.\d+)?)'),
    RegExp(r'll=(-?\d+(?:\.\d+)?),\s*(-?\d+(?:\.\d+)?)'),
  ];

  for (final pattern in patterns) {
    final match = pattern.firstMatch(trimmed);
    if (match == null) continue;

    final latitude = double.tryParse(match.group(1) ?? '');
    final longitude = double.tryParse(match.group(2) ?? '');
    if (latitude == null || longitude == null) continue;
    if (latitude < -90 ||
        latitude > 90 ||
        longitude < -180 ||
        longitude > 180) {
      return null;
    }
    return GeoPoint(latitude: latitude, longitude: longitude);
  }

  return null;
}
