import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../../data/datasources/booking_remote_datasource.dart';
import '../../data/models/booking_model.dart';
import '../../data/repositories/booking_repository_impl.dart';
import '../../domain/repositories/booking_repository.dart';
import '../../../../core/network/dio_client.dart';

final bookingRepositoryProvider = Provider<BookingRepository>((ref) {
  final dio = ref.watch(dioProvider);
  return BookingRepositoryImpl(BookingRemoteDataSource(dio));
});

final bookingsProvider =
    AsyncNotifierProvider<BookingsListNotifier, List<BookingModel>>(
  BookingsListNotifier.new,
);

class BookingsListNotifier extends AsyncNotifier<List<BookingModel>> {
  late BookingRepository _repository;
  Timer? _pollTimer;

  @override
  FutureOr<List<BookingModel>> build() async {
    _repository = ref.watch(bookingRepositoryProvider);
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      refreshSilent();
    });
    ref.onDispose(() {
      _pollTimer?.cancel();
    });
    try {
      return await _repository.getBookings();
    } catch (_) {
      if (state.hasValue && state.value != null) {
        return state.value!;
      }
      return const [];
    }
  }

  Future<void> refreshSilent() async {
    try {
      final items = await _repository.getBookings();
      state = AsyncValue.data(items);
    } catch (_) {}
  }
}

final bookingDetailProvider = FutureProvider.family<BookingModel, String>((ref, id) async {
  final repo = ref.watch(bookingRepositoryProvider);
  return repo.getBooking(id);
});

typedef AvailableSlotsParams = ({String subServiceId, String pincode, String date});

final availableSlotsProvider = FutureProvider.family<List<String>, AvailableSlotsParams>((ref, params) async {
  final repo = ref.watch(bookingRepositoryProvider);
  return repo.getAvailableSlots(params.subServiceId, params.pincode, params.date);
});

final bookingActionProvider = StateNotifierProvider<BookingActionNotifier, AsyncValue<void>>((ref) {
  final dio = ref.watch(dioProvider);
  final dataSource = BookingRemoteDataSource(dio);
  return BookingActionNotifier(ref.watch(bookingRepositoryProvider), ref, dataSource);
});

class BookingActionNotifier extends StateNotifier<AsyncValue<void>> {
  final BookingRepository _repository;
  final Ref _ref;
  final BookingRemoteDataSource _dataSource;

  BookingActionNotifier(this._repository, this._ref, this._dataSource)
      : super(const AsyncValue.data(null));

  Future<void> cancelBooking(String id, String reason) async {
    try {
      state = const AsyncValue.loading();
      await _repository.cancelBooking(id, reason);
      state = const AsyncValue.data(null);
      _ref.invalidate(bookingsProvider);
      _ref.invalidate(bookingDetailProvider(id));
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> submitReview(String bookingId, int rating, String? comment) async {
    try {
      state = const AsyncValue.loading();
      await _dataSource.submitReview(bookingId, rating, comment);
      state = const AsyncValue.data(null);
      _ref.invalidate(bookingDetailProvider(bookingId));
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> approveRevision(String bookingId) async {
    try {
      state = const AsyncValue.loading();
      await _dataSource.approveRevision(bookingId);
      state = const AsyncValue.data(null);
      _ref.invalidate(bookingDetailProvider(bookingId));
      _ref.invalidate(bookingsProvider);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> rejectRevision(String bookingId) async {
    try {
      state = const AsyncValue.loading();
      await _dataSource.rejectRevision(bookingId);
      state = const AsyncValue.data(null);
      _ref.invalidate(bookingDetailProvider(bookingId));
      _ref.invalidate(bookingsProvider);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }
}
