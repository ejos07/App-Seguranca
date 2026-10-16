import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;

class Api {
  // ATENÇÃO: Coloque aqui o IPv4 exato que está no ipconfig HOJE.
  // Se o roteador reiniciou, o final do IP pode ter mudado!
  static const String baseUrl = 'http://172.16.7.198:8000';

  // Evita a tela ficar "carregando para sempre" se o servidor não responder
  static const Duration _timeout = Duration(seconds: 20);

  static Map<String, String> get _headers => {
        'Content-Type': 'application/json; charset=UTF-8',
        'Accept': 'application/json',
      };

  static Uri _url(String endpoint) => Uri.parse('$baseUrl$endpoint');

  static Future<http.Response> get(String endpoint) async {
    try {
      return await http.get(_url(endpoint), headers: _headers).timeout(_timeout);
    } catch (e) {
      print('EXCEÇÃO DE REDE [GET $endpoint]: $e');
      rethrow;
    }
  }

  static Future<http.Response> post(String endpoint, Map<String, dynamic> body) async {
    try {
      return await http
          .post(_url(endpoint), headers: _headers, body: jsonEncode(body))
          .timeout(_timeout);
    } catch (e) {
      print('EXCEÇÃO DE REDE [POST $endpoint]: $e');
      rethrow;
    }
  }

  // NOVO: usado para editar registros
  static Future<http.Response> put(String endpoint, Map<String, dynamic> body) async {
    try {
      return await http
          .put(_url(endpoint), headers: _headers, body: jsonEncode(body))
          .timeout(_timeout);
    } catch (e) {
      print('EXCEÇÃO DE REDE [PUT $endpoint]: $e');
      rethrow;
    }
  }

  // NOVO: usado para excluir registros (ex.: DELETE /api/gsd/{id})
  static Future<http.Response> delete(String endpoint) async {
    try {
      return await http.delete(_url(endpoint), headers: _headers).timeout(_timeout);
    } catch (e) {
      print('EXCEÇÃO DE REDE [DELETE $endpoint]: $e');
      rethrow;
    }
  }
}
