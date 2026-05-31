import 'inspection_photo.dart';

class Inspection {
  final String id;
  final String jobId;
  String title;
  String inspector;
  DateTime date;
  String notes; // general observation for this visit
  final DateTime createdAt;
  List<InspectionPhoto> photos;
  List<String> categories;

  Inspection({
    required this.id,
    required this.jobId,
    required this.title,
    required this.inspector,
    required this.date,
    required this.createdAt,
    this.notes = '',
    List<InspectionPhoto>? photos,
    List<String>? categories,
  })  : photos = photos ?? [],
        categories = categories ?? [];

  int get photoCount => photos.length;
  int get flaggedCount => photos.where((p) => p.isFlagged).length;

  String get dateLabel {
    const m = [
      'Jan','Feb','Mar','Apr','May','Jun',
      'Jul','Aug','Sep','Oct','Nov','Dec'
    ];
    return '${m[date.month - 1]} ${date.day}, ${date.year}';
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'jobId': jobId,
        'title': title,
        'inspector': inspector,
        'date': date.toIso8601String(),
        'createdAt': createdAt.toIso8601String(),
        'notes': notes,
        'photos': photos.map((p) => p.toJson()).toList(),
        'categories': categories,
      };

  factory Inspection.fromJson(Map<String, dynamic> json) => Inspection(
        id: json['id'] as String,
        jobId: json['jobId'] as String,
        title: json['title'] as String? ?? 'Inspection',
        inspector: json['inspector'] as String? ?? '',
        date: DateTime.parse(json['date'] as String),
        createdAt: DateTime.parse(json['createdAt'] as String),
        notes: json['notes'] as String? ?? '',
        photos: (json['photos'] as List<dynamic>?)
                ?.map((p) =>
                    InspectionPhoto.fromJson(p as Map<String, dynamic>))
                .toList() ??
            [],
        categories:
            (json['categories'] as List<dynamic>?)?.cast<String>() ?? [],
      );
}
