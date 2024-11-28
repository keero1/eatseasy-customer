import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class Environment {
  static String get fileName {
    if (kReleaseMode) {
      return '.env.production';
    }

      return '.env.development';
  }

  static String get googleApiKey {
    return 'AIzaSyCBrZpYQFIWHQfgX4wvjzY5cC4JWDvu9XI';
  }

   static String get googleApiKey2 {
    return 'AIzaSyCBrZpYQFIWHQfgX4wvjzY5cC4JWDvu9XI';
  }

// balik mo sa dating url https://eatseasy-customer-partner-rider-backend-28fd.vercel.app
    static String get appBaseUrl {
    return 'http://localhost:57621';
  }

// https://eatseasy-payment-backend.vercel.app
   static String get paymentUrl {
    return 'http://localhost:5040';
  }
}
