/// Coarse India district centroids for offline reverse-geocode.
/// Precise GPS is never stored — only `district` and a 0.1° `geo_cell`.
class District {
  final String name;
  final String state;
  final double lat;
  final double lng;
  const District(this.name, this.state, this.lat, this.lng);
}

class GeoStamp {
  final String district;
  final String state;
  final String geoCell;
  final bool selfDeclared;
  final String source;
  const GeoStamp({
    required this.district,
    required this.state,
    required this.geoCell,
    this.selfDeclared = false,
    this.source = 'lookup',
  });

  Map<String, dynamic> toJson() => {
        'district': district,
        'state': state,
        'geo_cell': geoCell,
        'selfDeclared': selfDeclared,
        'source': source,
      };
}

/// Round to 0.1° so a cell is ~11 km, not a pin.
String geoCellOf(double lat, double lng) {
  String one(double n) => ((n * 10).round() / 10).toStringAsFixed(1);
  return '${one(lat)},${one(lng)}';
}

const indiaDistricts = <District>[
  District('Mumbai', 'Maharashtra', 19.0760, 72.8777),
  District('Pune', 'Maharashtra', 18.5204, 73.8567),
  District('Nagpur', 'Maharashtra', 21.1458, 79.0882),
  District('Thane', 'Maharashtra', 19.2183, 72.9781),
  District('Central Delhi', 'Delhi', 28.6448, 77.2167),
  District('New Delhi', 'Delhi', 28.6139, 77.2090),
  District('Chennai', 'Tamil Nadu', 13.0827, 80.2707),
  District('Coimbatore', 'Tamil Nadu', 11.0168, 76.9558),
  District('Bengaluru Urban', 'Karnataka', 12.9716, 77.5946),
  District('Hyderabad', 'Telangana', 17.3850, 78.4867),
  District('Kolkata', 'West Bengal', 22.5726, 88.3639),
  District('Howrah', 'West Bengal', 22.5958, 88.2636),
  District('Ahmedabad', 'Gujarat', 23.0225, 72.5714),
  District('Jaipur', 'Rajasthan', 26.9124, 75.7873),
  District('Lucknow', 'Uttar Pradesh', 26.8467, 80.9462),
  District('Varanasi', 'Uttar Pradesh', 25.3176, 82.9739),
  District('Patna', 'Bihar', 25.5941, 85.1376),
  District('Ranchi', 'Jharkhand', 23.3441, 85.3096),
  District('Bhubaneswar', 'Odisha', 20.2961, 85.8245),
  District('Raipur', 'Chhattisgarh', 21.2514, 81.6296),
  District('Bhopal', 'Madhya Pradesh', 23.2599, 77.4126),
  District('Indore', 'Madhya Pradesh', 22.7196, 75.8577),
  District('Chandigarh', 'Chandigarh', 30.7333, 76.7794),
  District('Amritsar', 'Punjab', 31.6340, 74.8723),
  District('Srinagar', 'Jammu and Kashmir', 34.0837, 74.7973),
  District('Shimla', 'Himachal Pradesh', 31.1048, 77.1734),
  District('Mandi', 'Himachal Pradesh', 31.7083, 76.9315),
  District('Yavatmal', 'Maharashtra', 20.3897, 78.1307),
  District('Ghaziabad', 'Uttar Pradesh', 28.6692, 77.4538),
  District('Dehradun', 'Uttarakhand', 30.3165, 78.0322),
  District('Guwahati', 'Assam', 26.1445, 91.7362),
  District('Imphal West', 'Manipur', 24.8170, 93.9368),
  District('Aizawl', 'Mizoram', 23.7271, 92.7176),
  District('Kohima', 'Nagaland', 25.6751, 94.1086),
  District('Shillong', 'Meghalaya', 25.5788, 91.8933),
  District('Agartala', 'Tripura', 23.8315, 91.2868),
  District('Itanagar', 'Arunachal Pradesh', 27.0844, 93.6053),
  District('Gangtok', 'Sikkim', 27.3389, 88.6065),
  District('Thiruvananthapuram', 'Kerala', 8.5241, 76.9366),
  District('Ernakulam', 'Kerala', 9.9816, 76.2999),
  District('Visakhapatnam', 'Andhra Pradesh', 17.6868, 83.2185),
  District('Vijayawada', 'Andhra Pradesh', 16.5062, 80.6480),
  District('Panaji', 'Goa', 15.4909, 73.8278),
  District('Raigad', 'Maharashtra', 18.5158, 73.1822),
  District('Nashik', 'Maharashtra', 19.9975, 73.7898),
];

District? districtByName(String name) {
  final n = name.trim().toLowerCase();
  for (final d in indiaDistricts) {
    if (d.name.toLowerCase() == n) return d;
  }
  return null;
}

District nearestDistrict(double lat, double lng) {
  District best = indiaDistricts.first;
  var bestD = 1e18;
  for (final d in indiaDistricts) {
    final dy = d.lat - lat;
    final dx = (d.lng - lng) * 0.8; // coarse lon shrink
    final dist = dy * dy + dx * dx;
    if (dist < bestD) {
      bestD = dist;
      best = d;
    }
  }
  return best;
}

GeoStamp stampFromLatLng(double lat, double lng) {
  final d = nearestDistrict(lat, lng);
  return GeoStamp(
    district: d.name,
    state: d.state,
    geoCell: geoCellOf(lat, lng),
    selfDeclared: false,
    source: 'gps-coarse',
  );
}

GeoStamp stampDeclared(String districtName) {
  final d = districtByName(districtName);
  final lat = d?.lat ?? 20.0;
  final lng = d?.lng ?? 77.0;
  return GeoStamp(
    district: d?.name ?? districtName,
    state: d?.state ?? '',
    geoCell: geoCellOf(lat, lng),
    selfDeclared: true,
    source: 'self-declared',
  );
}
