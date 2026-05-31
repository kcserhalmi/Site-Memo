import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/job.dart';
import '../models/inspection.dart';
import '../models/inspection_photo.dart';

class AppProvider extends ChangeNotifier {
  List<Job> _jobs = [];
  String? _selectedSiteId;
  String? _selectedInspectionId;
  final _uuid = const Uuid();

  List<Job> get jobs => _jobs;
  List<Job> get activeJobs => _jobs.where((j) => j.status == 'active').toList();
  List<Job> get completedJobs =>
      _jobs.where((j) => j.status == 'completed').toList();

  // Currently selected site for camera
  Job? get selectedSite => _selectedSiteId == null
      ? null
      : _jobs.firstWhere((j) => j.id == _selectedSiteId!,
          orElse: () => _jobs.isNotEmpty ? _jobs.first : _jobs.first);

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

  // ── Persistence ────────────────────────────────────────────────────────────

  Future<void> loadData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('jobs_v3');
      if (raw != null) {
        final list = jsonDecode(raw) as List<dynamic>;
        _jobs = list.map((e) => Job.fromJson(e as Map<String, dynamic>)).toList();
      } else {
        _seedSampleData();
      }
    } catch (_) {
      _seedSampleData();
    }
    // Auto-select first active site + its latest inspection
    _autoSelect();
    notifyListeners();
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

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          'jobs_v3', jsonEncode(_jobs.map((j) => j.toJson()).toList()));
    } catch (_) {}
  }

  // ── Sample data ────────────────────────────────────────────────────────────

  void _seedSampleData() {
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
    await _persist();
    notifyListeners();
    return job;
  }

  Future<void> editJob(String jobId, String name, String location) async {
    final i = _jobs.indexWhere((j) => j.id == jobId);
    if (i == -1) return;
    _jobs[i].name = name;
    _jobs[i].location = location;
    _jobs[i].updatedAt = DateTime.now();
    await _persist();
    notifyListeners();
  }

  Future<void> deleteJob(String jobId) async {
    _jobs.removeWhere((j) => j.id == jobId);
    if (_selectedSiteId == jobId) {
      _selectedSiteId = _jobs.isNotEmpty ? _jobs.first.id : null;
      _selectedInspectionId = null;
      _autoSelect();
    }
    await _persist();
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
    await _persist();
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
    await _persist();
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
    await _persist();
    notifyListeners();
    return insp;
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
    await _persist();
    notifyListeners();
  }

  Future<void> deleteInspection(String jobId, String inspectionId) async {
    final i = _jobs.indexWhere((j) => j.id == jobId);
    if (i == -1) return;
    _jobs[i].inspections.removeWhere((insp) => insp.id == inspectionId);
    _jobs[i].updatedAt = DateTime.now();
    if (_selectedInspectionId == inspectionId) {
      _selectedInspectionId = _jobs[i].inspections.isNotEmpty
          ? _jobs[i].inspections.first.id
          : null;
    }
    await _persist();
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
    await _persist();
    notifyListeners();
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
    await _persist();
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
    await _persist();
    notifyListeners();
  }

  Future<void> deletePhoto(
      String jobId, String inspectionId, String photoId) async {
    final ji = _jobs.indexWhere((j) => j.id == jobId);
    if (ji == -1) return;
    final ii =
        _jobs[ji].inspections.indexWhere((i) => i.id == inspectionId);
    if (ii == -1) return;
    _jobs[ji].inspections[ii].photos.removeWhere((p) => p.id == photoId);
    _jobs[ji].updatedAt = DateTime.now();
    await _persist();
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
    _jobs[ji].inspections[ii].photos[pi].imagePath = newImagePath;
    await _persist();
    notifyListeners();
  }

  String generateId() => _uuid.v4();
}
