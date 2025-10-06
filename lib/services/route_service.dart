// Archivo: lib/services/route_service.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';

class RouteService {
  static List<LatLng> _decodePolyline(String encodedPolyline) {
    PolylinePoints polylinePoints = PolylinePoints();
    List<PointLatLng> result = polylinePoints.decodePolyline(encodedPolyline);

    List<LatLng> points =
        result.map((point) => LatLng(point.latitude, point.longitude)).toList();

    return points;
  }

  // ⭐️ NUEVO: Función genérica para solicitar una ruta a OSRM (simple)
  static Future<Map<String, dynamic>?> getRoute(
      LatLng start, LatLng end, String profile) async {
    return _fetchRoute(start, end, profile, alternatives: false);
  }

  // Función interna para solicitar rutas (puede pedir alternativas)
  static Future<Map<String, dynamic>?> _fetchRoute(
      LatLng start, LatLng end, String profile,
      {bool alternatives = false}) async {
    final coords =
        '${start.longitude},${start.latitude};${end.longitude},${end.latitude}';

    final alternativesParam = alternatives ? '&alternatives=true' : '';

    final url = Uri.parse(
        'http://router.project-osrm.org/route/v1/$profile/$coords?geometries=polyline&overview=full$alternativesParam');

    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        final routes = json['routes'] as List?;

        if (routes != null && routes.isNotEmpty) {
          final routeData = routes.first;
          final String encodedPolyline = routeData['geometry'] as String;

          return {
            'points': _decodePolyline(encodedPolyline),
            'distance': (routeData['distance'] as num).toDouble(),
            'duration': (routeData['duration'] as num).toDouble(),
            'raw_routes': routes,
          };
        }
      }
    } catch (e) {
      debugPrint('Error al obtener ruta con perfil $profile: $e');
    }
    return null;
  }

  // Función principal para obtener las dos rutas
  static Future<List<Map<String, dynamic>>> getTwoRoutes(
      LatLng start, LatLng end) async {
    List<Map<String, dynamic>> results = [];

    // 1. Intentar obtener la Ruta A (principal) y sus alternativas de conducción
    final mainRouteResult =
        await _fetchRoute(start, end, 'driving', alternatives: true);

    if (mainRouteResult != null) {
      final rawRoutes = mainRouteResult['raw_routes'] as List;

      // Agregar Ruta A (principal)
      results.add({
        'points': mainRouteResult['points'],
        'distance': mainRouteResult['distance'],
        'duration': mainRouteResult['duration'],
      });

      // 2. Intentar obtener Ruta B de la alternativa de conducción
      if (rawRoutes.length > 1) {
        final routeDataB = rawRoutes[1];
        results.add({
          'points': _decodePolyline(routeDataB['geometry'] as String),
          'distance': (routeDataB['distance'] as num).toDouble(),
          'duration': (routeDataB['duration'] as num).toDouble(),
        });
      }
    }

    // 3. Si no se obtuvieron 2 rutas, forzar una ruta de BIKE para que la segunda línea sea visible.
    if (results.length < 2) {
      final alternateRoute = await _fetchRoute(start, end, 'bike');

      if (alternateRoute != null) {
        results.add(alternateRoute);
      }
    }

    return results.take(2).toList();
  }
}
