import 'inspection.dart';

class Job {
  final String id;
  String name;
  String location;
  String status; // 'active' | 'completed'
  final DateTime createdAt;
  DateTime updatedAt;
  List<Inspection> inspections;

  Job({
    required this.id,
    required this.name,
    required this.location,
    this.status = 'active',
    required this.createdAt,
    required this.updatedAt,
    List<Inspection>? inspections,
  }) : inspections = inspections ?? [];

  int get inspectionCount => inspections.length;
  int get photoCount =>
      inspections.fold(0, (sum, i) => sum + i.photos.length);

  DateTime get lastActivityDate => inspections.isEmpty
      ? updatedAt
      : inspections
          .map((i) => i.date)
          .reduce((a, b) => a.isAfter(b) ? a : b);

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'location': location,
        'status': status,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'inspections': inspections.map((i) => i.toJson()).toList(),
      };

  factory Job.fromJson(Map<String, dynamic> json) => Job(
        id: json['id'] as String,
        name: json['name'] as String,
        location: json['location'] as String,
        status: json['status'] as String? ?? 'active',
        createdAt: DateTime.parse(json['createdAt'] as String),
        updatedAt: DateTime.parse(json['updatedAt'] as String),
        inspections: (json['inspections'] as List<dynamic>?)
                ?.map((i) =>
                    Inspection.fromJson(i as Map<String, dynamic>))
                .toList() ??
            [],
      );
}
