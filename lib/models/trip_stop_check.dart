import 'bike_trip_plan.dart';

/// Conferência MANUAL de uma parada. Não afirma disponibilidade de serviço.
/// Ligada à rota/etapa/posição exatas para evitar falsos positivos ao mudar
/// a divisão dos dias ou a alternativa de percurso.
class TripStopCheck {
  const TripStopCheck({
    required this.day,
    required this.routeIndex,
    required this.endDistanceMeters,
    required this.latitude,
    required this.longitude,
    required this.checkedAt,
    this.accessChecked = false,
    this.waterChecked = false,
    this.overnightChecked = false,
    this.notes = '',
  });

  final int day;
  final int routeIndex;
  final double endDistanceMeters;
  final double latitude;
  final double longitude;
  final DateTime checkedAt;
  final bool accessChecked;
  final bool waterChecked;
  final bool overnightChecked;
  final String notes;

  bool get hasDetails => accessChecked || waterChecked || overnightChecked ||
      notes.trim().isNotEmpty;

  bool matches({required BikeTripDayPlan stage, required int selectedRouteIndex}) =>
      day == stage.day && routeIndex == selectedRouteIndex &&
      (endDistanceMeters - stage.endDistanceMeters).abs() <= 250 &&
      (latitude - stage.stopLatitude).abs() <= 0.00005 &&
      (longitude - stage.stopLongitude).abs() <= 0.00005;

  Map<String, Object?> toJson() => <String, Object?>{
    'day': day,
    'routeIndex': routeIndex,
    'endDistanceMeters': endDistanceMeters,
    'latitude': latitude,
    'longitude': longitude,
    'checkedAt': checkedAt.toIso8601String(),
    'accessChecked': accessChecked,
    'waterChecked': waterChecked,
    'overnightChecked': overnightChecked,
    'notes': notes.trim().length > 500 ? notes.trim().substring(0, 500) : notes.trim(),
  };

  factory TripStopCheck.fromJson(Map<String, dynamic> json) {
    final day = json['day'];
    final routeIndex = json['routeIndex'];
    final endDistance = (json['endDistanceMeters'] as num?)?.toDouble();
    final latitude = (json['latitude'] as num?)?.toDouble();
    final longitude = (json['longitude'] as num?)?.toDouble();
    final checkedAt = json['checkedAt'] is String
        ? DateTime.tryParse(json['checkedAt'] as String) : null;
    if (day is! int || day < 1 || day > 730 ||
        routeIndex is! int || routeIndex < 0 || routeIndex > 10 ||
        endDistance == null || !endDistance.isFinite || endDistance < 0 ||
        latitude == null || !latitude.isFinite || latitude.abs() > 90 ||
        longitude == null || !longitude.isFinite || longitude.abs() > 180 ||
        checkedAt == null) {
      throw const FormatException('Conferência de parada inválida');
    }
    final rawNotes = json['notes'] is String ? (json['notes'] as String).trim() : '';
    return TripStopCheck(
      day: day, routeIndex: routeIndex, endDistanceMeters: endDistance,
      latitude: latitude, longitude: longitude, checkedAt: checkedAt,
      accessChecked: json['accessChecked'] == true,
      waterChecked: json['waterChecked'] == true,
      overnightChecked: json['overnightChecked'] == true,
      notes: rawNotes.length > 500 ? rawNotes.substring(0, 500) : rawNotes,
    );
  }
}
