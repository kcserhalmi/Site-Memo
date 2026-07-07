import 'package:flutter_test/flutter_test.dart';
import 'package:site_memo/models/inspection_photo.dart';
import 'package:site_memo/providers/app_provider.dart';

// All tests run in demo mode: no uid, so Firestore/Storage are never touched.
void main() {
  Future<AppProvider> demoProvider() async {
    final p = AppProvider();
    await p.enterDemoMode();
    return p;
  }

  test('demo mode seeds sample jobs and selects a site', () async {
    final p = await demoProvider();
    expect(p.jobs, isNotEmpty);
    expect(p.activeJobs, isNotEmpty);
    expect(p.selectedSite, isNotNull);
    expect(p.selectedInspection, isNotNull);
    expect(p.isDemoMode, true);
  });

  test('job CRUD: create, edit, complete, delete', () async {
    final p = await demoProvider();
    final before = p.jobs.length;

    final job = await p.createJob('Test Tower', 'Main St');
    expect(p.jobs.length, before + 1);
    expect(p.selectedSite!.id, job.id);

    await p.editJob(job.id, 'Test Tower II', 'Broadway');
    expect(p.jobs.firstWhere((j) => j.id == job.id).name, 'Test Tower II');

    await p.completeJob(job.id);
    expect(p.completedJobs.any((j) => j.id == job.id), true);
    // selection must fall back to another active job, never crash
    expect(p.selectedSite, isNotNull);

    await p.deleteJob(job.id);
    expect(p.jobs.any((j) => j.id == job.id), false);
  });

  test('selectedSite is null-safe with zero jobs', () async {
    final p = await demoProvider();
    for (final job in [...p.jobs]) {
      await p.deleteJob(job.id);
    }
    expect(p.jobs, isEmpty);
    expect(p.selectedSite, isNull); // used to throw StateError
    expect(p.selectedInspection, isNull);
  });

  test('inspection lifecycle and photo add/flag', () async {
    final p = await demoProvider();
    final job = await p.createJob('Photo Job', 'Site A');
    final insp = await p.createInspection(
      jobId: job.id,
      title: 'Framing check',
      inspector: 'Kevin',
      date: DateTime.now(),
      categories: ['LEVEL 1'],
    );

    final photo = InspectionPhoto(
      id: p.generateId(),
      jobId: job.id,
      inspectionId: insp.id,
      imagePath: '/nonexistent/x.jpg',
      category: 'LEVEL 1',
      timestamp: DateTime.now(),
    );
    await p.addPhoto(job.id, insp.id, photo);
    expect(p.totalPhotoCount, 1);

    await p.toggleFlag(job.id, insp.id, photo.id);
    expect(p.totalFlaggedCount, 1);
    await p.toggleFlag(job.id, insp.id, photo.id);
    expect(p.totalFlaggedCount, 0);
  });

  test('deletePhotos supports undo at original positions', () async {
    final p = await demoProvider();
    final job = await p.createJob('Undo Job', 'Site B');
    final insp = await p.createInspection(
      jobId: job.id,
      title: 'T',
      inspector: '',
      date: DateTime.now(),
    );
    final ids = <String>[];
    for (int i = 0; i < 3; i++) {
      final photo = InspectionPhoto(
        id: 'photo_$i',
        jobId: job.id,
        inspectionId: insp.id,
        imagePath: '/x/$i.jpg',
        timestamp: DateTime.now(),
      );
      ids.add(photo.id);
      await p.addPhoto(job.id, insp.id, photo);
    }

    // Delete the middle photo, then undo — order must be restored
    await p.deletePhotos(job.id, insp.id, ['photo_1']);
    var photos = p.jobs
        .firstWhere((j) => j.id == job.id)
        .inspections
        .first
        .photos;
    expect(photos.map((x) => x.id), ['photo_0', 'photo_2']);
    expect(p.canUndoDelete, true);

    p.undoDeletePhotos();
    photos = p.jobs
        .firstWhere((j) => j.id == job.id)
        .inspections
        .first
        .photos;
    expect(photos.map((x) => x.id), ['photo_0', 'photo_1', 'photo_2']);
    expect(p.canUndoDelete, false);

    // Batch delete all, undo restores all
    await p.deletePhotos(job.id, insp.id, ids);
    expect(p.totalPhotoCount, 0);
    p.undoDeletePhotos();
    expect(p.totalPhotoCount, 3);
  });

  test('deleting the selected inspection moves selection safely', () async {
    final p = await demoProvider();
    final job = await p.createJob('Sel Job', 'Site C');
    final a = await p.createInspection(
        jobId: job.id, title: 'A', inspector: '', date: DateTime.now());
    expect(p.selectedInspection!.id, a.id);
    await p.deleteInspection(job.id, a.id);
    expect(
        p.jobs.firstWhere((j) => j.id == job.id).inspections, isEmpty);
  });
}
