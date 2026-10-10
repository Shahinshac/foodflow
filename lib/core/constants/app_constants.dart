class AppConstants {
  static const String appName = 'FoodFlow';
  
  // Environment override (can be set during build: flutter build apk --dart-define=API_URL=https://your-api.onrender.com)
  static const String _envApiUrl = String.fromEnvironment('API_URL');
  
  // Local network IP address of development machine
  static const String localBaseUrl = 'http://localhost:8000';
  
  // Cloud production API URL (verified live Render deployment)
  static const String cloudBaseUrl = 'https://foodflow-api-lcxo.onrender.com';
  
  // Active environment toggle: Set to true for cloud by default
  static const bool useCloud = bool.fromEnvironment('USE_CLOUD', defaultValue: true);
  
  // Active Base URL
  static String get baseUrl {
    if (_envApiUrl.isNotEmpty) {
      return _envApiUrl;
    }
    return useCloud ? cloudBaseUrl : localBaseUrl;
  }
  
  static const String authTokenKey = 'auth_token';
  static const String userKey = 'user_data';

  // Google OAuth Client IDs
  static const String googleWebClientId = '946437330680-9r4mutghresee1heq36ailmtrh7drtv1.apps.googleusercontent.com';
  static const String googleAndroidClientId = '946437330680-87ma1tf4dg56rcp0mk4moi00r7f3159m.apps.googleusercontent.com';
  static const String googleIosClientId = '946437330680-drp10qt4b720rhdl6h19uruj1pqirsat.apps.googleusercontent.com';

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

