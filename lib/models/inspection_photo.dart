class InspectionPhoto {
  final String id;
  final String jobId;
  final String inspectionId;
  String imagePath; // mutable so annotation can replace it
  String? voiceNotePath;
  String? transcription;
  String? caption;
  String category;
  bool isFlagged;
  final DateTime timestamp;

  InspectionPhoto({
    required this.id,
    required this.jobId,
    required this.inspectionId,
    required this.imagePath,
    this.voiceNotePath,
    this.transcription,
    this.caption,
    this.category = 'UNTAGGED',
    this.isFlagged = false,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'jobId': jobId,
        'inspectionId': inspectionId,
        'imagePath': imagePath,
        'voiceNotePath': voiceNotePath,
        'transcription': transcription,
        'caption': caption,
        'category': category,
        'isFlagged': isFlagged,
        'timestamp': timestamp.toIso8601String(),
      };

  factory InspectionPhoto.fromJson(Map<String, dynamic> json) =>
      InspectionPhoto(
        id: json['id'] as String,
        jobId: json['jobId'] as String,
        inspectionId: json['inspectionId'] as String? ?? '',
        imagePath: json['imagePath'] as String,
        voiceNotePath: json['voiceNotePath'] as String?,
        transcription: json['transcription'] as String?,
        caption: json['caption'] as String?,
        category: json['category'] as String? ?? 'UNTAGGED',
        isFlagged: json['isFlagged'] as bool? ?? false,
        timestamp: DateTime.parse(json['timestamp'] as String),
      );
}
