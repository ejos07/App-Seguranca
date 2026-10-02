import 'dart:convert';
import 'package:http/http.dart' as http;

class Api {
  // SE ESTIVER NO EMULADOR ANDROID: Mantenha 'http://10.0.2.2:8000/api'
  // SE ESTIVER NO CELULAR FÍSICO (Via Cabo/Wi-Fi): Use o IP da sua máquina na rede
  static const String baseUrl = 'http://172.16.1.76:8000/api';
  static Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  // Método POST genérico com tratamento de exceções móveis
  static Future<http.Response> post(String endpoint, Map<String, dynamic> body) async {
    try {
      final url = Uri.parse('$baseUrl$endpoint');
      final response = await http.post(
        url,
        headers: _headers,
        body: jsonEncode(body),
      );
      return response;
    } catch (e) {
      print('EXCEÇÃO DE REDE [POST $endpoint]: $e');
      rethrow;
    }
  }

  // Método GET genérico com tratamento de exceções móveis
  static Future<http.Response> get(String endpoint) async {
    try {
      final url = Uri.parse('$baseUrl$endpoint');
      final response = await http.get(
        url,
        headers: _headers,
      );
      return response;
    } catch (e) {
      print('EXCEÇÃO DE REDE [GET $endpoint]: $e');
      rethrow;
    }
  }
}