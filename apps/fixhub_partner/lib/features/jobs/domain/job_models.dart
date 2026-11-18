/// Domain models for jobs/bookings in the technician app

class JobAddress {
  final String? label;
  final String line1;
  final String? line2;
  final String? landmark;
  final String city;
  final String state;
  final String pincode;
  final double? latitude;
  final double? longitude;

  const JobAddress({
    this.label,
    required this.line1,
    this.line2,
    this.landmark,
    required this.city,
    required this.state,
    required this.pincode,
    this.latitude,
    this.longitude,
  });

  factory JobAddress.fromJson(Map<String, dynamic> json) => JobAddress(
    label: json['label'] as String?,
    line1: json['line1'] as String? ?? '',
    line2: json['line2'] as String?,
    landmark: json['landmark'] as String?,
    city: json['city'] as String? ?? '',
    state: json['state'] as String? ?? '',
    pincode: json['pincode'] as String? ?? '',
    latitude: json['latitude'] != null
        ? double.tryParse(json['latitude'].toString())
        : null,
    longitude: json['longitude'] != null
        ? double.tryParse(json['longitude'].toString())
        : null,
  );

  String get fullAddress {
    final parts = [line1, if (line2 != null) line2!, city, pincode];
    return parts.join(', ');
  }
}

class JobCustomer {
  final String id;
  final String? name;
  final String phone;
  final String? email;

  const JobCustomer({
    required this.id,
    this.name,
    required this.phone,
    this.email,
  });

  factory JobCustomer.fromJson(Map<String, dynamic> json) {
    final user = json['user'] as Map<String, dynamic>?;
    return JobCustomer(
      id: (user?['id'] ?? json['id']) as String,
      name: (user?['name'] ?? json['name']) as String?,
      phone: (user?['phone'] ?? json['phone']) as String,
      email: (user?['email'] ?? json['email']) as String?,
    );
  }

  String get displayName => name ?? phone;
}

class JobSubService {
  final String id;
  final String name;
  final String? categoryName;
  final double? basePrice;
  final int? estimatedDurationMins;

  const JobSubService({
    required this.id,
    required this.name,
    this.categoryName,
    this.basePrice,
    this.estimatedDurationMins,
  });

  factory JobSubService.fromJson(Map<String, dynamic> json) {
    final category = json['category'] as Map<String, dynamic>?;
    return JobSubService(
      id: json['id'] as String,
      name: json['name'] as String,
      categoryName: category?['name'] as String?,
      basePrice: json['basePrice'] != null
          ? double.tryParse(json['basePrice'].toString())
          : null,
      estimatedDurationMins: json['estimatedDurationMins'] as int?,
    );
  }
}

class JobMedia {
  final String id;
  final String url;
  final String type; // IMAGE, VIDEO, DOCUMENT
  final String? phase; // BEFORE_SERVICE, DURING_SERVICE, AFTER_SERVICE

  const JobMedia({
    required this.id,
    required this.url,
    required this.type,
    this.phase,
  });

  factory JobMedia.fromJson(Map<String, dynamic> json) => JobMedia(
    id: json['id'] as String,
    url: json['url'] as String,
    type: json['type'] as String? ?? 'IMAGE',
    phase: json['phase'] as String?,
  );
}

class JobTimelineEntry {
  final String status;
  final String? note;
  final DateTime createdAt;

  const JobTimelineEntry({
    required this.status,
    this.note,
    required this.createdAt,
  });

  factory JobTimelineEntry.fromJson(Map<String, dynamic> json) =>
      JobTimelineEntry(
        status: json['status'] as String,
        note: json['note'] as String?,
        createdAt: DateTime.parse(json['createdAt'] as String),
      );
}

class Job {
  final String id;
  final String bookingNumber;
  final String status;
  final DateTime scheduledDate;
  final String scheduledSlot;
  final String? description;
  final double totalAmount;
  final String? notes;
  // Price revision fields
  final double? revisedAmount;
  final double? additionalAmount;
  final String? priceRevisionDescription;
  final String? priceRevisionNote;
  // Cancellation/failure fields
  final DateTime? cancelledAt;
  final String? cancelReason;
  final DateTime? failedAt;
  final String? failureReason;
  final JobCustomer customer;
  final JobSubService subService;
  final JobAddress address;
  final List<JobMedia> media;
  final List<JobTimelineEntry> timeline;
  final DateTime createdAt;
  final DateTime? completedAt;

  const Job({
    required this.id,
    required this.bookingNumber,
    required this.status,
    required this.scheduledDate,
    required this.scheduledSlot,
    this.description,
    required this.totalAmount,
    this.notes,
    this.revisedAmount,
    this.additionalAmount,
    this.priceRevisionDescription,
    this.priceRevisionNote,
    this.cancelledAt,
    this.cancelReason,
    this.failedAt,
    this.failureReason,
    required this.customer,
    required this.subService,
    required this.address,
    this.media = const [],
    this.timeline = const [],
    required this.createdAt,
    this.completedAt,
  });

  factory Job.fromJson(Map<String, dynamic> json) => Job(
    id: json['id'] as String,
    bookingNumber: json['bookingNumber'] as String,
    status: json['status'] as String,
    scheduledDate: DateTime.parse(json['scheduledDate'] as String),
    scheduledSlot: json['scheduledSlot'] as String,
    description: json['description'] as String?,
    totalAmount: double.tryParse(json['totalAmount'].toString()) ?? 0,
    notes: json['notes'] as String?,
    revisedAmount: json['revisedAmount'] != null
        ? double.tryParse(json['revisedAmount'].toString())
        : null,
    additionalAmount: json['additionalAmount'] != null
        ? double.tryParse(json['additionalAmount'].toString())
        : null,
    priceRevisionDescription: json['priceRevisionDescription'] as String?,
    priceRevisionNote: json['priceRevisionNote'] as String?,
    cancelledAt: json['cancelledAt'] != null
        ? DateTime.tryParse(json['cancelledAt'] as String)
        : null,
    cancelReason: json['cancelReason'] as String?,
    failedAt: json['failedAt'] != null
        ? DateTime.tryParse(json['failedAt'] as String)
        : null,
    failureReason: json['failureReason'] as String?,
    customer: JobCustomer.fromJson(json['customer'] as Map<String, dynamic>),
    subService: JobSubService.fromJson(
      json['subService'] as Map<String, dynamic>,
    ),
    address: JobAddress.fromJson(json['address'] as Map<String, dynamic>),
    media:
        (json['media'] as List<dynamic>?)
            ?.map((m) => JobMedia.fromJson(m as Map<String, dynamic>))
            .toList() ??
        [],
    timeline:
        (json['timeline'] as List<dynamic>?)
            ?.map((t) => JobTimelineEntry.fromJson(t as Map<String, dynamic>))
            .toList() ??
        [],
    createdAt: DateTime.parse(json['createdAt'] as String),
    completedAt: json['completedAt'] != null
        ? DateTime.parse(json['completedAt'] as String)
        : null,
  );

  /// An active job includes PRICE_REVISION_PENDING (tech is waiting for customer)
  bool get isActive =>
      const ['ACCEPTED', 'EN_ROUTE', 'ARRIVED', 'IN_PROGRESS', 'PRICE_REVISION_PENDING']
          .contains(status);

  bool get isAssigned => status == 'ASSIGNED';
  bool get isCompleted => status == 'COMPLETED';
  bool get isCancelled => status == 'CANCELLED';
  bool get isFailed => status == 'FAILED';
  bool get isPriceRevisionPending => status == 'PRICE_REVISION_PENDING';
  bool get isEnRoute => status == 'EN_ROUTE';
  bool get isArrived => status == 'ARRIVED';
  bool get isInProgress => status == 'IN_PROGRESS';

  /// The effective price (revised if approved, otherwise original)
  double get effectiveAmount => revisedAmount ?? totalAmount;

  /// Human-readable status label
  String get displayStatus => status.replaceAll('_', ' ');

  Job copyWith({
    String? id,
    String? bookingNumber,
    String? status,
    DateTime? scheduledDate,
    String? scheduledSlot,
    String? description,
    double? totalAmount,
    String? notes,
    double? revisedAmount,
    String? priceRevisionNote,
    JobCustomer? customer,
    JobSubService? subService,
    JobAddress? address,
    List<JobMedia>? media,
    List<JobTimelineEntry>? timeline,
    DateTime? createdAt,
    DateTime? completedAt,
  }) {
    return Job(
      id: id ?? this.id,
      bookingNumber: bookingNumber ?? this.bookingNumber,
      status: status ?? this.status,
      scheduledDate: scheduledDate ?? this.scheduledDate,
      scheduledSlot: scheduledSlot ?? this.scheduledSlot,
      description: description ?? this.description,
      totalAmount: totalAmount ?? this.totalAmount,
      notes: notes ?? this.notes,
      revisedAmount: revisedAmount ?? this.revisedAmount,
      priceRevisionNote: priceRevisionNote ?? this.priceRevisionNote,
      cancelledAt: cancelledAt,
      cancelReason: cancelReason,
      failedAt: failedAt,
      failureReason: failureReason,
      customer: customer ?? this.customer,
      subService: subService ?? this.subService,
      address: address ?? this.address,
      media: media ?? this.media,
      timeline: timeline ?? this.timeline,
      createdAt: createdAt ?? this.createdAt,
      completedAt: completedAt ?? this.completedAt,
    );
  }
}

class PaginatedJobs {
  final List<Job> items;
  final int total;
  final int page;
  final int totalPages;
  final bool hasNextPage;

  const PaginatedJobs({
    required this.items,
    required this.total,
    required this.page,
    required this.totalPages,
    required this.hasNextPage,
  });

  factory PaginatedJobs.fromJson(Map<String, dynamic> json) {
    final meta = json['meta'] as Map<String, dynamic>;
    return PaginatedJobs(
      items: (json['items'] as List<dynamic>)
          .map((j) => Job.fromJson(j as Map<String, dynamic>))
          .toList(),
      total: meta['total'] as int,
      page: meta['page'] as int,
      totalPages: meta['totalPages'] as int,
      hasNextPage: meta['hasNextPage'] as bool,
    );
  }
}
