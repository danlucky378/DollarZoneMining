import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;

class AuthService {
  static const _serviceId = 'service_hyu6qrk';
  static const _templateId = 'template_o2qvfv4';
  static const _publicKey = 'e2SxStjwqQE_WiWX8';

  static Future<String> sendOtpEmail(String userEmail) async {
    // generate random 6-digit OTP
    final otp = (100000 + Random().nextInt(900000)).toString();

    final url = Uri.parse('https://api.emailjs.com/api/v1.0/email/send');

    final response = await http.post(
      url,
      headers: {
        'origin': 'http://localhost',
        'Content-Type': 'application/json',
      },
      body: json.encode({
        'service_id': _serviceId,
        'template_id': _templateId,
        'user_id': _publicKey,
        'template_params': {
          'user_email': userEmail,
          'otp_code': otp,
        },
      }),
    );

    if (response.statusCode == 200) {
      print('OTP sent successfully');
      return otp;
    } else {
      print('Error sending OTP: ${response.body}');
      throw Exception('Failed to send OTP');
    }
  }
}