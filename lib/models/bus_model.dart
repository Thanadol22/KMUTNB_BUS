class BusModel {
  final String id;
  final String driverName;
  final String driverPhone;
  final String licensePlate;
  final double latitude;
  final double longitude;
  final String status;
  final String eta;

  BusModel({
    required this.id,
    required this.driverName,
    required this.driverPhone,
    required this.licensePlate,
    required this.latitude,
    required this.longitude,
    required this.status,
    required this.eta,
  });
}
