import 'package:flutter_test/flutter_test.dart';
import 'package:site_memo/models/inspection.dart';
import 'package:site_memo/models/inspection_photo.dart';
import 'package:site_memo/models/job.dart';

void main() {
  group('InspectionPhoto JSON', () {
    test('roundtrips every field', () {
      final photo = InspectionPhoto(
        id: 'p1',
        jobId: 'j1',
        inspectionId: 'i1',
        imagePath: '/photos/a.jpg',
        storageUrl: 'https://example.com/a.jpg',
        transcription: 'crack in slab',
        caption: 'NE corner',
        category: 'FOUNDATION',
        isFlagged: true,
        timestamp: DateTime(2026, 7, 6, 14, 30),
      );
      final restored = InspectionPhoto.fromJson(photo.toJson());
      expect(restored.id, 'p1');
      expect(restored.jobId, 'j1');
      expect(restored.inspectionId, 'i1');
      expect(restored.imagePath, '/photos/a.jpg');
      expect(restored.storageUrl, 'https://example.com/a.jpg');
      expect(restored.transcription, 'crack in slab');
      expect(restored.caption, 'NE corner');
      expect(restored.category, 'FOUNDATION');
      expect(restored.isFlagged, true);
      expect(restored.timestamp, DateTime(2026, 7, 6, 14, 30));
    });

    test('tolerates missing optional fields (old documents)', () {
      final restored = InspectionPhoto.fromJson({
        'id': 'p1',
        'jobId': 'j1',
        'imagePath': '/a.jpg',
        'timestamp': DateTime(2026, 1, 1).toIso8601String(),
      });
      expect(restored.storageUrl, isNull);
      expect(restored.category, 'UNTAGGED');
      expect(restored.isFlagged, false);
      expect(restored.inspectionId, '');
    });
  });

  group('Inspection JSON', () {
    test('roundtrips with photos, categories and notes', () {
      final insp = Inspection(
        id: 'i1',
        jobId: 'j1',
        title: 'Pre-pour',
        inspector: 'Kevin',
        date: DateTime(2026, 7, 1),
        createdAt: DateTime(2026, 7, 1),
        notes: 'windy day',
        status: 'submitted',
        categories: ['FOUNDATION', 'DAMAGE'],
        categoryNotes: {'FOUNDATION': 'east side ok'},
        photos: [
          InspectionPhoto(
            id: 'p1',
            jobId: 'j1',
            inspectionId: 'i1',
            imagePath: '/a.jpg',
            timestamp: DateTime(2026, 7, 1, 9),
          ),
        ],
      );
      final restored = Inspection.fromJson(insp.toJson());
      expect(restored.title, 'Pre-pour');
      expect(restored.status, 'submitted');
      expect(restored.categories, ['FOUNDATION', 'DAMAGE']);
      expect(restored.categoryNotes['FOUNDATION'], 'east side ok');
      expect(restored.photos.length, 1);
      expect(restored.flaggedCount, 0);
    });
  });

  group('Job JSON', () {
    test('roundtrips with nested inspections', () {
      final job = Job(
        id: 'j1',
        name: 'Warehouse',
        location: 'Unit 7',
        status: 'active',
        createdAt: DateTime(2026, 6, 1),
        updatedAt: DateTime(2026, 7, 1),
        inspections: [
          Inspection(
            id: 'i1',
            jobId: 'j1',
            title: 'Walkthrough',
            inspector: '',
            date: DateTime(2026, 6, 15),
            createdAt: DateTime(2026, 6, 15),
          ),
        ],
      );
      final restored = Job.fromJson(job.toJson());
      expect(restored.name, 'Warehouse');
      expect(restored.inspectionCount, 1);
      expect(restored.photoCount, 0);
      expect(restored.updatedAt, DateTime(2026, 7, 1));
    });
  });
}
