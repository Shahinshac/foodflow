class AppConstants {
  static const String appName = 'FoodFlow';
  
  // Environment override (can be set during build: flutter build apk --dart-define=API_URL=https://your-api.onrender.com)
  static const String _envApiUrl = String.fromEnvironment('API_URL');
  
  // Local network IP address of development machine
  static const String localBaseUrl = 'http://172.24.149.198:8000';
  
  // Cloud production API URL (verified live Render deployment)
  static const String cloudBaseUrl = 'https://foodflow-api-lcxo.onrender.com';
  
  // Active environment toggle: Set to true for cloud, false for local
  static const bool useCloud = bool.fromEnvironment('USE_CLOUD', defaultValue: false);
  
  // Active Base URL
  static String get baseUrl {
    if (_envApiUrl.isNotEmpty) {
      return _envApiUrl;
    }
    return useCloud ? cloudBaseUrl : localBaseUrl;
  }
  
  static const String authTokenKey = 'auth_token';
  static const String userKey = 'user_data';

  /// Resolves relative upload paths to full accessible URLs for image loading
  static String resolveImageUrl(String? url) {
    if (url == null || url.trim().isEmpty) {
      return 'https://images.unsplash.com/photo-1546069901-ba9599a7e63c?auto=format&fit=crop&w=800&q=80';
    }
    if (url.startsWith('http://') || url.startsWith('https://')) {
      return url;
    }
    final activeBase = baseUrl;
    if (url.startsWith('/')) {
      return '$activeBase$url';
    }
    return '$activeBase/$url';
  }
}

