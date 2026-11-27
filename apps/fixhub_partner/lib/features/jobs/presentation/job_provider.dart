import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/job_repository.dart';
import '../domain/job_models.dart';

// ── Current active job ───────────────────────────────────────────
final currentJobProvider = FutureProvider<Job?>((ref) async {
  return ref.read(jobRepositoryProvider).getCurrentJob();
});

// ── Upcoming jobs (ACCEPTED + EN_ROUTE statuses) ─────────────────
final upcomingJobsProvider = FutureProvider<PaginatedJobs>((ref) async {
  return ref.read(jobRepositoryProvider).listJobs(
    status: 'ACCEPTED',
    limit: 10,
  );
});

// ── My jobs (all statuses, paginated) ────────────────────────────
final myJobsProvider = FutureProvider.family<PaginatedJobs, String?>((ref, status) async {
  return ref.read(jobRepositoryProvider).listJobs(status: status);
});

// ── Assigned jobs count (pending technician acceptance) ───────────
final assignedJobsCountProvider = Provider<int>((ref) {
  final jobsAsync = ref.watch(myJobsProvider(null));
  return jobsAsync.value?.items.where((j) => j.status == 'ASSIGNED').length ?? 0;
});

// ── Job history ──────────────────────────────────────────────────
final jobHistoryProvider = FutureProvider<PaginatedJobs>((ref) async {
  return ref.read(jobRepositoryProvider).listJobHistory();
});

// ── Job details ──────────────────────────────────────────────────
final jobDetailsProvider = FutureProvider.family<Job, String>((ref, id) async {
  return ref.read(jobRepositoryProvider).getJobDetails(id);
});

// ── Active job status controller ─────────────────────────────────
final activeJobProvider =
    AsyncNotifierProvider<ActiveJobNotifier, Job?>(ActiveJobNotifier.new);

class ActiveJobNotifier extends AsyncNotifier<Job?> {
  late JobRepository _repository;

  @override
  FutureOr<Job?> build() async {
    _repository = ref.watch(jobRepositoryProvider);
    return _repository.getCurrentJob();
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _repository.getCurrentJob());
  }

  Future<Job?> acceptJob(String id) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final job = await _repository.acceptJob(id);
      // Invalidate related providers so lists refresh
      _invalidateRelatedProviders();
      return job;
    });
    return state.value;
  }

  Future<void> rejectJob(String id, String reason) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await _repository.rejectJob(id, reason);
      _invalidateRelatedProviders();
      return _repository.getCurrentJob();
    });
  }

  Future<Job?> updateStatus(
    String id,
    String status, {
    String? note,
    double? latitude,
    double? longitude,
    String? otp,
  }) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final job = await _repository.updateJobStatus(
        id,
        status,
        note: note,
        latitude: latitude,
        longitude: longitude,
        otp: otp,
      );
      // Invalidate related providers so they pick up the new status
      _invalidateRelatedProviders();
      // Also invalidate the specific job details
      ref.invalidate(jobDetailsProvider(id));
      return job;
    });
    if (state.hasError) {
      throw state.error!;
    }
    return state.value;
  }

  Future<Job?> requestAdditionalCharge({
    required String id,
    required double amount,
    String? description,
    String? reason,
  }) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final job = await _repository.requestAdditionalCharge(
        id,
        amount: amount,
        description: description,
        reason: reason,
      );
      ref.invalidate(jobDetailsProvider(id));
      _invalidateRelatedProviders();
      return job;
    });
    return state.value;
  }

  Future<Job?> proposeRevision(
    String id,
    double revisedAmount,
    String note,
  ) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final job = await _repository.proposeRevision(id, revisedAmount, note: note);
      ref.invalidate(jobDetailsProvider(id));
      return job;
    });
    if (state.hasError) {
      throw state.error!;
    }
    return state.value;
  }

  Future<Job?> finalizeAmount({
    required String id,
    required double finalAdditionalAmount,
    required String paymentMethod,
  }) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final job = await _repository.finalizeAmount(
        id,
        finalAdditionalAmount: finalAdditionalAmount,
        paymentMethod: paymentMethod,
      );
      ref.invalidate(jobDetailsProvider(id));
      _invalidateRelatedProviders();
      return job;
    });
    if (state.hasError) {
      throw state.error!;
    }
    return state.value;
  }

  Future<Job?> verifyCompletionOtp(String id, String otp) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final job = await _repository.verifyCompletionOtp(id, otp);
      ref.invalidate(jobDetailsProvider(id));
      _invalidateRelatedProviders();
      return job;
    });
    if (state.hasError) {
      throw state.error!;
    }
    return state.value;
  }

  /// Invalidate all list providers that might show stale data after a status change.
  void _invalidateRelatedProviders() {
    ref.invalidate(currentJobProvider);
    ref.invalidate(upcomingJobsProvider);
    ref.invalidate(jobHistoryProvider);
    // myJobsProvider is family-based; invalidate common status filters
    ref.invalidate(myJobsProvider(null));
    ref.invalidate(myJobsProvider('ASSIGNED'));
    ref.invalidate(myJobsProvider('ACCEPTED'));
  }
}
