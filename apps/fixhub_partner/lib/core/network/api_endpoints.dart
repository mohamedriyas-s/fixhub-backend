/// FixHub Partner API Endpoint Constants
///
/// All paths are relative to the base URL: http://10.0.2.2:3000/api/v1
class ApiEndpoints {
  ApiEndpoints._();

  // ── Auth ────────────────────────────────────────────────────────
  static const String sendOtp = '/auth/send-otp';
  static const String verifyOtp = '/auth/verify-otp';
  static const String refreshToken = '/auth/refresh';
  static const String logout = '/auth/logout';
  static const String me = '/auth/me';
  static const String registerDevice = '/auth/device';

  // ── Technician Profile ──────────────────────────────────────────
  static const String technicianProfile = '/technicians/profile';
  static const String technicianAvailability = '/technicians/availability';
  static const String technicianLocation = '/technicians/location';
  static const String technicianHeartbeat = '/technicians/heartbeat';

  // ── Technician Documents ────────────────────────────────────────
  static const String technicianDocuments = '/technicians/documents';
  static String technicianDocument(String id) => '/technicians/documents/$id';

  // ── Technician Specializations ──────────────────────────────────
  static const String technicianSpecializations =
      '/technicians/specializations';

  // ── Technician Service Areas ────────────────────────────────────
  static const String technicianServiceAreas = '/technicians/service-areas';

  // ── Technician Jobs ─────────────────────────────────────────────
  static const String technicianJobs = '/technicians/jobs';
  static const String technicianCurrentJob = '/technicians/jobs/current';
  static const String technicianJobHistory = '/technicians/jobs/history';
  static String technicianJobDetails(String id) => '/technicians/jobs/$id';
  static String technicianJobAccept(String id) =>
      '/technicians/jobs/$id/accept';
  static String technicianJobReject(String id) =>
      '/technicians/jobs/$id/reject';
  static String technicianJobStatus(String id) =>
      '/technicians/jobs/$id/status';
  static String technicianJobProposeRevision(String id) =>
      '/technicians/jobs/$id/propose-revision';
  static String technicianJobAdditionalCharge(String id) =>
      '/technicians/jobs/$id/additional-charge';
  static String technicianJobFinalizeAmount(String id) =>
      '/technicians/jobs/$id/finalize-amount';
  static String technicianJobDepartNextSlot(String id) =>
      '/technicians/jobs/$id/depart-next-slot';
  static String technicianJobVerifyCompletionOtp(String id) =>
      '/bookings/$id/verify-completion-otp';

  // ── Technician Job Offers (broadcast eligibility) ───────────────
  static const String technicianOffers = '/technicians/offers';
  static const String technicianOffersCount = '/technicians/offers/count';
  static String technicianOfferAccept(String id) =>
      '/technicians/offers/$id/accept';
  static String technicianOfferReject(String id) =>
      '/technicians/offers/$id/reject';

  // ── Technician Earnings ─────────────────────────────────────────
  static const String technicianEarnings = '/technicians/earnings';
  static const String technicianEarningsHistory =
      '/technicians/earnings/history';

  // ── Technician Ratings ──────────────────────────────────────────
  static const String technicianRatings = '/technicians/ratings';
  static const String technicianRatingsSummary = '/technicians/ratings/summary';

  // ── Catalog & Public ────────────────────────────────────────────
  static const String catalogCategories = '/catalog/categories';
  static String catalogCategory(String id) => '/catalog/categories/$id';
  static const String catalogServices = '/catalog/services';
  static String catalogService(String id) => '/catalog/services/$id';
  static const String serviceAreas = '/service-areas';

  // ── Notifications ───────────────────────────────────────────────
  static const String notifications = '/notifications';
  static String notificationRead(String id) => '/notifications/$id/read';
  static const String notificationReadAll = '/notifications/read-all';
  static String notificationDelete(String id) => '/notifications/$id';
  static const String notificationPreferences = '/notifications/preferences';
}
