import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/job.dart';
import '../models/inspection.dart';
import '../models/inspection_photo.dart';
import '../services/photo_storage_service.dart';
import '../utils/file_utils.dart';

class AppProvider extends ChangeNotifier {
  List<Job> _jobs = [];
  String? _selectedSiteId;
  String? _selectedInspectionId;
  String? _uid;
  final _uuid = const Uuid();

  List<Job> get jobs => _jobs;
  List<Job> get activeJobs => _jobs.where((j) => j.status == 'active').toList();
  List<Job> get completedJobs =>
      _jobs.where((j) => j.status == 'completed').toList();

  // Currently selected site for camera
  Job? get selectedSite {
    if (_selectedSiteId == null) return null;
    for (final j in _jobs) {
      if (j.id == _selectedSiteId) return j;
    }
    return _jobs.isNotEmpty ? _jobs.first : null;
  }

  // Currently selected inspection for camera
  Inspection? get selectedInspection {
    final site = selectedSite;
    if (site == null || _selectedInspectionId == null) return null;
    final matches =
        site.inspections.where((i) => i.id == _selectedInspectionId!);
    return matches.isNotEmpty ? matches.first : null;
  }

  void setSelectedContext(String siteId, String inspectionId) {
    _selectedSiteId = siteId;
    _selectedInspectionId = inspectionId;
    notifyListeners();
  }

  // ── Persistence (Firestore — one document per Job under users/{uid}/jobs) ──

  CollectionReference<Map<String, dynamic>>? get _jobsCollection => _uid == null
      ? null
      : FirebaseFirestore.instance.collection('users').doc(_uid).collection('jobs');

  /// Called by AuthGate whenever the signed-in user changes (sign in, sign
  /// out, or switching accounts on the same device). Reloads that user's
  /// own data so one device never shows a different account's jobs/photos.
  Future<void> setCurrentUser(String? uid) async {
    if (uid == _uid) return;
    _uid = uid;
    if (uid == null) {
      _jobs = [];
      _selectedSiteId = null;
      _selectedInspectionId = null;
      notifyListeners();
      return;
    }
    await loadData();
  }

  Future<void> loadData() async {
    final collection = _jobsCollection;
    if (collection == null) return;
    try {
      final snapshot = await collection.get();
      if (snapshot.docs.isEmpty) {
        // Confirmed empty (not a network failure) — seed sample data so a
        // brand-new signup isn't staring at a blank app.
        await _seedSampleData();
      } else {
        _jobs = snapshot.docs.map((d) => Job.fromJson(d.data())).toList();
      }
    } catch (_) {
      // Fetch failed (e.g. offline with no local cache yet) — leave _jobs as
      // whatever it already was. Do NOT fall back to fake sample data here;
      // that would risk clobbering a real user's view of their own data.
    }
    // Auto-select first active site + its latest inspection
    _autoSelect();
    notifyListeners();
    // Retry any photo uploads that didn't finish last session
    syncPendingUploads();
  }

  Future<void> _persistJob(Job job) async {
    final collection = _jobsCollection;
    if (collection == null) return;
    try {
      await collection.doc(job.id).set(job.toJson());
    } catch (_) {}
  }

  Future<void> _deleteJobRemote(String jobId) async {
    final collection = _jobsCollection;
    if (collection == null) return;
    try {
      await collection.doc(jobId).delete();
    } catch (_) {}
  }

  void _autoSelect() {
    final active = activeJobs;
    if (active.isEmpty) return;
    _selectedSiteId ??= active.first.id;
    final site = active.firstWhere((j) => j.id == _selectedSiteId!,
        orElse: () => active.first);
    if (site.inspections.isNotEmpty && _selectedInspectionId == null) {
      final sorted = [...site.inspections]..sort((a, b) => b.date.compareTo(a.date));
      _selectedInspectionId = sorted.first.id;
    }
  }

  // ── Sample data ────────────────────────────────────────────────────────────

  Future<void> _seedSampleData() async {
    final now = DateTime.now();
    final job1Id = _uuid.v4();
    final job2Id = _uuid.v4();

    final insp1 = Inspection(
      id: _uuid.v4(),
      jobId: job1Id,
      title: 'Initial walkthrough',
      inspector: 'Field Inspector',
      date: now.subtract(const Duration(days: 3)),
      createdAt: now.subtract(const Duration(days: 3)),
    );
    final insp2 = Inspection(
      id: _uuid.v4(),
      jobId: job1Id,
      title: 'Foundation check',
      inspector: 'Field Inspector',
      date: now,
      createdAt: now,
    );
    final insp3 = Inspection(
      id: _uuid.v4(),
      jobId: job2Id,
      title: 'Pre-pour inspection',
      inspector: 'Field Inspector',
      date: now.subtract(const Duration(days: 1)),
      createdAt: now.subtract(const Duration(days: 1)),
    );

    _jobs = [
      Job(
        id: job1Id,
        name: 'Commercial Reno',
        location: '4th Ave & Main — Block C',
        status: 'active',
        createdAt: now.subtract(const Duration(days: 10)),
        updatedAt: now,
        inspections: [insp2, insp1],
      ),
      Job(
        id: job2Id,
        name: 'Residential Unit B',
        location: 'Oak Street — 2nd Floor',
        status: 'active',
        createdAt: now.subtract(const Duration(days: 5)),
        updatedAt: now.subtract(const Duration(days: 1)),
        inspections: [insp3],
      ),
      Job(
        id: _uuid.v4(),
        name: 'Warehouse Facility',
        location: 'Industrial Blvd — Unit 7',
        status: 'completed',
        createdAt: now.subtract(const Duration(days: 30)),
        updatedAt: now.subtract(const Duration(days: 7)),
      ),
    ];
    _selectedSiteId = job1Id;
    _selectedInspectionId = insp2.id;
    for (final job in _jobs) {
      await _persistJob(job);
    }
  }

  // ── Site (Job) CRUD ────────────────────────────────────────────────────────

  Future<Job> createJob(String name, String location) async {
    final job = Job(
      id: _uuid.v4(),
      name: name,
      location: location,
      status: 'active',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    _jobs.insert(0, job);
    _selectedSiteId = job.id;
    _selectedInspectionId = null;
    await _persistJob(job);
    notifyListeners();
    return job;
  }

  Future<void> editJob(String jobId, String name, String location) async {
    final i = _jobs.indexWhere((j) => j.id == jobId);
    if (i == -1) return;
    _jobs[i].name = name;
    _jobs[i].location = location;
    _jobs[i].updatedAt = DateTime.now();
    await _persistJob(_jobs[i]);
    notifyListeners();
  }

  Future<void> deleteJob(String jobId) async {
    final ji = _jobs.indexWhere((j) => j.id == jobId);
    if (ji != -1) {
      for (final insp in _jobs[ji].inspections) {
        for (final photo in insp.photos) {
          _cleanupPhotoFiles(photo);
        }
      }
    }
    _jobs.removeWhere((j) => j.id == jobId);
    if (_selectedSiteId == jobId) {
      _selectedSiteId = _jobs.isNotEmpty ? _jobs.first.id : null;
      _selectedInspectionId = null;
      _autoSelect();
    }
    await _deleteJobRemote(jobId);
    notifyListeners();
  }

  Future<void> completeJob(String jobId) async {
    final i = _jobs.indexWhere((j) => j.id == jobId);
    if (i == -1) return;
    _jobs[i].status = 'completed';
    _jobs[i].updatedAt = DateTime.now();
    if (_selectedSiteId == jobId) {
      _selectedSiteId = null;
      _selectedInspectionId = null;
      _autoSelect();
    }
    await _persistJob(_jobs[i]);
    notifyListeners();
  }

  Future<void> updateInspectionCategories(
      String jobId, String inspectionId, List<String> categories) async {
    final ji = _jobs.indexWhere((j) => j.id == jobId);
    if (ji == -1) return;
    final ii =
        _jobs[ji].inspections.indexWhere((i) => i.id == inspectionId);
    if (ii == -1) return;
    _jobs[ji].inspections[ii].categories = List.from(categories);
    _jobs[ji].updatedAt = DateTime.now();
    await _persistJob(_jobs[ji]);
    notifyListeners();
  }

  Future<void> updateCategoryNote(
      String jobId, String inspectionId, String category, String note) async {
    final ji = _jobs.indexWhere((j) => j.id == jobId);
    if (ji == -1) return;
    final ii =
        _jobs[ji].inspections.indexWhere((i) => i.id == inspectionId);
    if (ii == -1) return;
    if (note.isEmpty) {
      _jobs[ji].inspections[ii].categoryNotes.remove(category);
    } else {
      _jobs[ji].inspections[ii].categoryNotes[category] = note;
    }
    await _persistJob(_jobs[ji]);
    notifyListeners();
  }

  // ── Inspection CRUD ────────────────────────────────────────────────────────

  Future<Inspection> createInspection({
    required String jobId,
    required String title,
    required String inspector,
    required DateTime date,
    List<String>? categories,
  }) async {
    final insp = Inspection(
      id: _uuid.v4(),
      jobId: jobId,
      title: title,
      inspector: inspector,
      categories: categories ?? [],
      date: date,
      createdAt: DateTime.now(),
    );
    final i = _jobs.indexWhere((j) => j.id == jobId);
    if (i == -1) return insp;
    _jobs[i].inspections.insert(0, insp);
    _jobs[i].updatedAt = DateTime.now();
    _selectedSiteId = jobId;
    _selectedInspectionId = insp.id;
    await _persistJob(_jobs[i]);
    notifyListeners();
    return insp;
  }

  Future<void> updateInspectionStatus(
      String jobId, String inspectionId, String status) async {
    final ji = _jobs.indexWhere((j) => j.id == jobId);
    if (ji == -1) return;
    final ii =
        _jobs[ji].inspections.indexWhere((i) => i.id == inspectionId);
    if (ii == -1) return;
    _jobs[ji].inspections[ii].status = status;
    await _persistJob(_jobs[ji]);
    notifyListeners();
  }

  Future<void> editInspection(
      String jobId, String inspectionId, String title, String inspector,
      DateTime date) async {
    final ji = _jobs.indexWhere((j) => j.id == jobId);
    if (ji == -1) return;
    final ii =
        _jobs[ji].inspections.indexWhere((i) => i.id == inspectionId);
    if (ii == -1) return;
    _jobs[ji].inspections[ii].title = title;
    _jobs[ji].inspections[ii].inspector = inspector;
    _jobs[ji].inspections[ii].date = date;
    _jobs[ji].updatedAt = DateTime.now();
    await _persistJob(_jobs[ji]);
    notifyListeners();
  }

  Future<void> deleteInspection(String jobId, String inspectionId) async {
    final i = _jobs.indexWhere((j) => j.id == jobId);
    if (i == -1) return;
    for (final insp in _jobs[i].inspections) {
      if (insp.id == inspectionId) {
        for (final photo in insp.photos) {
          _cleanupPhotoFiles(photo);
        }
      }
    }
    _jobs[i].inspections.removeWhere((insp) => insp.id == inspectionId);
    _jobs[i].updatedAt = DateTime.now();
    if (_selectedInspectionId == inspectionId) {
      _selectedInspectionId = _jobs[i].inspections.isNotEmpty
          ? _jobs[i].inspections.first.id
          : null;
    }
    await _persistJob(_jobs[i]);
    notifyListeners();
  }

  // ── Photos ─────────────────────────────────────────────────────────────────

  Future<void> addPhoto(
      String jobId, String inspectionId, InspectionPhoto photo) async {
    final ji = _jobs.indexWhere((j) => j.id == jobId);
    if (ji == -1) return;
    final ii =
        _jobs[ji].inspections.indexWhere((i) => i.id == inspectionId);
    if (ii == -1) return;
    _jobs[ji].inspections[ii].photos.add(photo);
    _jobs[ji].updatedAt = DateTime.now();
    await _persistJob(_jobs[ji]);
    notifyListeners();
    // Back up to cloud in the background — non-blocking so capture stays fast
    _uploadPhotoIfNeeded(_jobs[ji], photo);
  }

  // ── Cloud photo backup ─────────────────────────────────────────────────────

  final Set<String> _uploading = {};

  /// Uploads a photo to Firebase Storage if it has no cloud copy yet.
  /// Fire-and-forget: failures are silent and retried on next app load.
  Future<void> _uploadPhotoIfNeeded(Job job, InspectionPhoto photo) async {
    final uid = _uid;
    if (uid == null) return;
    if (photo.storageUrl != null || _uploading.contains(photo.id)) return;
    if (!fileExists(photo.imagePath)) return;
    _uploading.add(photo.id);
    try {
      final url =
          await PhotoStorageService.upload(uid, photo.id, photo.imagePath);
      photo.storageUrl = url;
      await _persistJob(job);
      notifyListeners();
    } catch (_) {
      // Offline or storage error — syncPendingUploads retries later.
    } finally {
      _uploading.remove(photo.id);
    }
  }

  /// Retries any photos that never made it to the cloud (e.g. captured
  /// offline). Called after load; safe to call any time.
  void syncPendingUploads() {
    for (final job in _jobs) {
      for (final insp in job.inspections) {
        for (final photo in insp.photos) {
          if (photo.storageUrl == null) _uploadPhotoIfNeeded(job, photo);
        }
      }
    }
  }

  /// Best-effort cleanup of a photo's local file and cloud copy.
  void _cleanupPhotoFiles(InspectionPhoto photo) {
    deleteLocalPhotoFile(photo.imagePath);
    final uid = _uid;
    if (uid != null && photo.storageUrl != null) {
      PhotoStorageService.delete(uid, photo.id);
    }
  }

  Future<void> toggleFlag(
      String jobId, String inspectionId, String photoId) async {
    final ji = _jobs.indexWhere((j) => j.id == jobId);
    if (ji == -1) return;
    final ii =
        _jobs[ji].inspections.indexWhere((i) => i.id == inspectionId);
    if (ii == -1) return;
    final pi = _jobs[ji].inspections[ii].photos
        .indexWhere((p) => p.id == photoId);
    if (pi == -1) return;
    _jobs[ji].inspections[ii].photos[pi].isFlagged =
        !_jobs[ji].inspections[ii].photos[pi].isFlagged;
    await _persistJob(_jobs[ji]);
    notifyListeners();
  }

  Future<void> updateNotes(
      String jobId, String inspectionId, String notes) async {
    final ji = _jobs.indexWhere((j) => j.id == jobId);
    if (ji == -1) return;
    final ii =
        _jobs[ji].inspections.indexWhere((i) => i.id == inspectionId);
    if (ii == -1) return;
    _jobs[ji].inspections[ii].notes = notes;
    _jobs[ji].updatedAt = DateTime.now();
    await _persistJob(_jobs[ji]);
    notifyListeners();
  }

  Future<void> updatePhotoCaption(
      String jobId, String inspectionId, String photoId, String? caption) async {
    final ji = _jobs.indexWhere((j) => j.id == jobId);
    if (ji == -1) return;
    final ii =
        _jobs[ji].inspections.indexWhere((i) => i.id == inspectionId);
    if (ii == -1) return;
    final pi = _jobs[ji].inspections[ii].photos
        .indexWhere((p) => p.id == photoId);
    if (pi == -1) return;
    _jobs[ji].inspections[ii].photos[pi].caption = caption;
    _jobs[ji].updatedAt = DateTime.now();
    await _persistJob(_jobs[ji]);
    notifyListeners();
  }

  Future<void> updatePhotoCategory(
      String jobId, String inspectionId, String photoId, String category) async {
    final ji = _jobs.indexWhere((j) => j.id == jobId);
    if (ji == -1) return;
    final ii =
        _jobs[ji].inspections.indexWhere((i) => i.id == inspectionId);
    if (ii == -1) return;
    final pi = _jobs[ji].inspections[ii].photos
        .indexWhere((p) => p.id == photoId);
    if (pi == -1) return;
    _jobs[ji].inspections[ii].photos[pi].category = category;
    _jobs[ji].updatedAt = DateTime.now();
    await _persistJob(_jobs[ji]);
    notifyListeners();
  }

  Future<void> updatePhotoVoiceNote(String jobId, String inspectionId,
      String photoId, String? voiceNotePath, String? transcription) async {
    final ji = _jobs.indexWhere((j) => j.id == jobId);
    if (ji == -1) return;
    final ii =
        _jobs[ji].inspections.indexWhere((i) => i.id == inspectionId);
    if (ii == -1) return;
    final pi = _jobs[ji].inspections[ii].photos
        .indexWhere((p) => p.id == photoId);
    if (pi == -1) return;
    _jobs[ji].inspections[ii].photos[pi].voiceNotePath = voiceNotePath;
    _jobs[ji].inspections[ii].photos[pi].transcription = transcription;
    _jobs[ji].updatedAt = DateTime.now();
    await _persistJob(_jobs[ji]);
    notifyListeners();
  }

  Future<void> deletePhoto(
      String jobId, String inspectionId, String photoId) async {
    final ji = _jobs.indexWhere((j) => j.id == jobId);
    if (ji == -1) return;
    final ii =
        _jobs[ji].inspections.indexWhere((i) => i.id == inspectionId);
    if (ii == -1) return;
    for (final p in _jobs[ji].inspections[ii].photos) {
      if (p.id == photoId) _cleanupPhotoFiles(p);
    }
    _jobs[ji].inspections[ii].photos.removeWhere((p) => p.id == photoId);
    _jobs[ji].updatedAt = DateTime.now();
    await _persistJob(_jobs[ji]);
    notifyListeners();
  }

  Future<void> updatePhotoImage(
      String jobId, String inspectionId, String photoId,
      String newImagePath) async {
    final ji = _jobs.indexWhere((j) => j.id == jobId);
    if (ji == -1) return;
    final ii =
        _jobs[ji].inspections.indexWhere((i) => i.id == inspectionId);
    if (ii == -1) return;
    final pi = _jobs[ji].inspections[ii].photos
        .indexWhere((p) => p.id == photoId);
    if (pi == -1) return;
    final photo = _jobs[ji].inspections[ii].photos[pi];
    // Annotated image replaces the original: drop the old local file and
    // stale cloud copy, then re-upload the new image.
    if (photo.imagePath != newImagePath) {
      deleteLocalPhotoFile(photo.imagePath);
    }
    photo.imagePath = newImagePath;
    photo.storageUrl = null;
    _jobs[ji].updatedAt = DateTime.now();
    await _persistJob(_jobs[ji]);
    notifyListeners();
    // Remove the stale remote copy first so the re-upload can't be
    // clobbered by the delete, then upload the annotated image.
    final job = _jobs[ji];
    final uid = _uid;
    () async {
      if (uid != null) await PhotoStorageService.delete(uid, photo.id);
      await _uploadPhotoIfNeeded(job, photo);
    }();
  }

  String generateId() => _uuid.v4();

  // ── Computed getters (cached by provider, not recalculated per-widget) ──────

  int get totalFlaggedCount => _jobs.fold(0, (sum, j) =>
      sum + j.inspections.fold(0, (s2, i) =>
          s2 + i.photos.where((p) => p.isFlagged).length));

  int get totalPhotoCount => _jobs.fold(0, (sum, j) => sum + j.photoCount);
}
