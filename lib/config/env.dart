const apiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'https://6qipli13v7.execute-api.us-east-2.amazonaws.com/api',
);
const entitiesBaseUrl = String.fromEnvironment(
  'ENTITIES_BASE_URL',
  defaultValue: 'https://f76y479xbj.execute-api.us-east-2.amazonaws.com',
);
const paymentsBaseUrl = String.fromEnvironment(
  'PAYMENTS_BASE_URL',
  defaultValue: 'https://6qipli13v7.execute-api.us-east-2.amazonaws.com/api',
);
const subscriptionPaymentsBaseUrl = String.fromEnvironment(
  'SUBSCRIPTION_PAYMENTS_BASE_URL',
  defaultValue: 'https://f76y479xbj.execute-api.us-east-2.amazonaws.com',
);
const carouselBaseUrl = String.fromEnvironment(
  'CAROUSEL_BASE_URL',
  defaultValue: 'https://f76y479xbj.execute-api.us-east-2.amazonaws.com',
);

/// QC-only: Admin key used to call v2 admin endpoints (ex: DELETE /admin/items/{pk}).
/// Prefer setting this via SharedPreferences at runtime; this is a build-time fallback.
const qcAdminApiKey = String.fromEnvironment(
  'QC_ADMIN_API_KEY',
  defaultValue: '',
);
