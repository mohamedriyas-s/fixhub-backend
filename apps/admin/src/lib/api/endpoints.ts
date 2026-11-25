export const endpoints = {
  // Auth
  auth: {
    adminLogin: '/auth/admin/login',
    refresh: '/auth/refresh',
    logout: '/auth/logout',
    me: '/auth/me',
  },

  // Admin — Dashboard
  admin: {
    dashboard: '/admin/dashboard',

    // Customers
    customers: '/admin/customers',
    customer: (id: string) => `/admin/customers/${id}`,
    customerStatus: (userId: string) => `/admin/customers/${userId}/status`,
    customerDetails: (id: string) => `/admin/customers/${id}/details`,
    customerNotifyProfile: (id: string) => `/admin/customers/${id}/notify-profile`,

    // Technicians
    technicians: '/admin/technicians',
    eligibleTechnicians: '/admin/technicians/eligible',
    technician: (id: string) => `/admin/technicians/${id}`,
    technicianStatus: (userId: string) => `/admin/technicians/${userId}/status`,
    technicianVerify: (id: string) => `/admin/technicians/${id}/verify`,
    technicianDetails: (id: string) => `/admin/technicians/${id}/details`,
    technicianSpecializations: (id: string) => `/admin/technicians/${id}/specializations`,
    technicianSpecialization: (id: string, subServiceId: string) =>
      `/admin/technicians/${id}/specializations/${subServiceId}`,
    technicianAreas: (id: string) => `/admin/technicians/${id}/areas`,
    technicianArea: (id: string, serviceAreaId: string) =>
      `/admin/technicians/${id}/areas/${serviceAreaId}`,

    // System
    auditLogs: '/admin/audit-logs',
    settings: '/admin/settings',

    // Pricing
    pricing: '/admin/pricing',
    pricingRule: (id: string) => `/admin/pricing/${id}`,

    // Coupons
    coupons: '/admin/coupons',
    coupon: (id: string) => `/admin/coupons/${id}`,
  },

  // Bookings (admin)
  bookings: {
    list: '/admin/bookings',
    history: '/admin/bookings/history',
    create: '/admin/bookings',
    detail: (id: string) => `/admin/bookings/${id}`,
    delete: (id: string) => `/admin/bookings/${id}`,
    assign: (id: string) => `/admin/bookings/${id}/assign`,
    notes: (id: string) => `/admin/bookings/${id}/notes`,
    cancel: (id: string) => `/admin/bookings/${id}/cancel`,
  },

  // Catalog (admin endpoints for listing, creating, etc.)
  catalog: {
    categories: '/admin/categories',
    category: (id: string) => `/admin/categories/${id}`,
    services: '/admin/services',
    service: (id: string) => `/admin/services/${id}`,
    // Admin CRUD
    createCategory: '/admin/categories',
    updateCategory: (id: string) => `/admin/categories/${id}`,
    deleteCategory: (id: string) => `/admin/categories/${id}`,
    createService: '/admin/services',
    updateService: (id: string) => `/admin/services/${id}`,
    updatePricing: (id: string) => `/admin/services/${id}/pricing`,
    deleteService: (id: string) => `/admin/services/${id}`,
  },

  // Service Areas
  serviceAreas: {
    list: '/admin/service-areas',
    create: '/admin/service-areas',
    update: (id: string) => `/admin/service-areas/${id}`,
    delete: (id: string) => `/admin/service-areas/${id}`,
    coverageRequests: '/admin/service-areas/coverage-requests',
    markCoverageHandled: (id: string) => `/admin/service-areas/coverage-requests/${id}/handled`,
  },

  // Payments
  payments: {
    list: '/admin/payments',
    refund: (id: string) => `/payments/${id}/refund`,
  },

  // Reports
  reports: {
    revenue: '/reports/revenue',
    bookings: '/reports/bookings',
    customers: '/reports/customers',
    technicians: '/reports/technicians',
    payments: '/reports/payments',
    cancellations: '/reports/cancellations',
    growth: '/reports/growth',
  },

  // Outbound broadcast notifications
  notifications: {
    list: '/notifications',
    send: '/notifications/send',
    markRead: (id: string) => `/notifications/${id}/read`,
    markAllRead: '/notifications/read-all',
    template: (key: string) => `/notifications/templates/${key}`,
    preferences: '/notifications/preferences',
  },

  // Admin-targeted real-time notifications (persisted events)
  adminNotifications: {
    list: '/admin/notifications',
    unreadCount: '/admin/notifications/unread-count',
    markRead: (id: string) => `/admin/notifications/${id}/read`,
    markAllRead: '/admin/notifications/read-all',
    delete: (id: string) => `/admin/notifications/${id}`,
    deleteAll: '/admin/notifications',
  },
} as const;
