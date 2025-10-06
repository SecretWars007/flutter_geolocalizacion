import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../services/route_service.dart';
import 'package:geolocator/geolocator.dart';

enum StartMode { gps, manual }

enum RouteSelection { none, routeA, routeB }

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapController mapController = MapController();

  LatLng? startPoint;
  LatLng? endPoint;

  List<LatLng> routeA = [];
  List<LatLng> routeB = [];

  bool loading = false;
  String infoA = '';
  String infoB = '';
  double? distanceA;
  double? distanceB;

  RouteSelection selectedRoute = RouteSelection.routeB;

  StartMode mode = StartMode.manual;

  final TextEditingController startLatController = TextEditingController();
  final TextEditingController startLngController = TextEditingController();
  final TextEditingController endLatController = TextEditingController();
  final TextEditingController endLngController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      mapController.move(LatLng(-16.5, -68.1), 13);
    });
  }

  Future<void> _useGpsAsStart() async {
    try {
      final pos = await Geolocator.getCurrentPosition();
      setState(() {
        startPoint = LatLng(pos.latitude, pos.longitude);
        startLatController.text = pos.latitude.toString();
        startLngController.text = pos.longitude.toString();
        mapController.move(startPoint!, 15);
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo obtener la ubicación')),
      );
    }
  }

  void _onTap(LatLng point) async {
    if (mode == StartMode.manual) {
      setState(() {
        if (startPoint == null) {
          startPoint = point;
          startLatController.text = point.latitude.toString();
          startLngController.text = point.longitude.toString();
        } else if (endPoint == null) {
          endPoint = point;
          endLatController.text = point.latitude.toString();
          endLngController.text = point.longitude.toString();
        } else {
          startPoint = point;
          endPoint = null;
          startLatController.text = point.latitude.toString();
          startLngController.text = point.longitude.toString();
          endLatController.clear();
          endLngController.clear();
          _resetRouteInfo();
        }
      });
    } else {
      setState(() {
        endPoint = point;
        endLatController.text = point.latitude.toString();
        endLngController.text = point.longitude.toString();
      });
    }

    if (startPoint != null && endPoint != null) {
      await _calculateRoutes();
    }
  }

  void _resetRouteInfo() {
    routeA = [];
    routeB = [];
    infoA = '';
    infoB = '';
    distanceA = null;
    distanceB = null;
    selectedRoute = RouteSelection.routeB;
  }

  Future<void> _calculateRoutes() async {
    if (startPoint == null || endPoint == null) return;
    setState(() {
      loading = true;
      _resetRouteInfo();
    });
    try {
      final results = await RouteService.getTwoRoutes(startPoint!, endPoint!);
      if (results.isNotEmpty) {
        setState(() {
          if (results.isNotEmpty) {
            routeA = results[0]['points'] as List<LatLng>;
            distanceA = results[0]['distance'] as double?;
            infoA = _formatInfo(distanceA, results[0]['duration'],
                includeTime: true);
          }

          if (results.length > 1) {
            routeB = results[1]['points'] as List<LatLng>;
            distanceB = results[1]['distance'] as double?;
            infoB = _formatInfo(distanceB, results[1]['duration'],
                includeTime: true);
          }
          selectedRoute = RouteSelection.routeB;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error obteniendo rutas: $e')),
      );
    } finally {
      setState(() => loading = false);
    }
  }

  Future<void> _updateRouteA() async {
    if (startPoint == null || endPoint == null) return;
    setState(() {
      loading = true;
      selectedRoute = RouteSelection.routeA;
    });
    try {
      final result =
          await RouteService.getRoute(startPoint!, endPoint!, 'driving');
      if (result != null) {
        setState(() {
          routeA = result['points'] as List<LatLng>;
          distanceA = result['distance'] as double?;
          infoA = _formatInfo(distanceA, result['duration'], includeTime: true);
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error actualizando Ruta A: $e')),
      );
    } finally {
      setState(() => loading = false);
    }
  }

  Future<void> _updateRouteB() async {
    if (startPoint == null || endPoint == null) return;
    setState(() {
      loading = true;
      selectedRoute = RouteSelection.routeB;
    });
    try {
      final result =
          await RouteService.getRoute(startPoint!, endPoint!, 'bike');
      if (result != null) {
        setState(() {
          routeB = result['points'] as List<LatLng>;
          distanceB = result['distance'] as double?;
          infoB = _formatInfo(distanceB, result['duration'], includeTime: true);
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error actualizando Ruta B: $e')),
      );
    } finally {
      setState(() => loading = false);
    }
  }

  String _formatInfo(double? distance, double? duration,
      {required bool includeTime}) {
    if (distance == null) return '';

    String distanceText;

    if (distance < 1000) {
      distanceText = '${distance.round()} m';
    } else {
      final km = (distance / 1000).toStringAsFixed(2);
      distanceText = '$km km';
    }

    if (!includeTime || duration == null) {
      return distanceText;
    }

    final mins = (duration / 60).round();
    return '$distanceText · $mins min';
  }

  List<Marker> _taxiMarkersAlong(List<LatLng> poly, int maxMarkers) {
    final markers = <Marker>[];
    if (poly.isEmpty) return markers;
    final step = (poly.length / (maxMarkers + 1)).floor();
    for (int i = step; i < poly.length; i += step) {
      if (markers.length >= maxMarkers) break;
      final p = poly[i];
      markers.add(Marker(
        point: p,
        width: 28,
        height: 28,
        child: SvgPicture.asset('assets/taxi.svg', width: 22, height: 22),
      ));
    }
    return markers;
  }

  @override
  Widget build(BuildContext context) {
    final markers = <Marker>[];

    // ⭐️ Marcador de Inicio (Restaurado)
    if (startPoint != null) {
      markers.add(Marker(
        point: startPoint!,
        width: 56,
        height: 56,
        child: Column(
          children: [
            const Icon(Icons.circle, color: Colors.green, size: 12),
            SvgPicture.asset('assets/taxi.svg', width: 36, height: 36),
          ],
        ),
      ));
    }

    // ⭐️ Marcador de Fin (Restaurado)
    if (endPoint != null) {
      markers.add(Marker(
        point: endPoint!,
        width: 56,
        height: 56,
        child: Column(
          children: [
            SvgPicture.asset('assets/taxi.svg', width: 36, height: 36),
            const Icon(Icons.flag, color: Colors.red, size: 12),
          ],
        ),
      ));
    }

    markers.addAll(_taxiMarkersAlong(routeA, 3));
    markers.addAll(_taxiMarkersAlong(routeB, 3));

    final double strokeA = selectedRoute == RouteSelection.routeA ? 8.0 : 6.0;
    final double strokeB = selectedRoute == RouteSelection.routeB ? 8.0 : 6.0;

    return Scaffold(
      appBar: AppBar(title: const Text('Mi Ruta de Escape')),
      body: Stack(
        children: [
          FlutterMap(
            mapController: mapController,
            options: MapOptions(
              onTap: (tapPosition, point) => _onTap(point),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.tumarca.nombre_de_tu_app_unico',
              ),
              if (routeA.isNotEmpty)
                PolylineLayer(
                  polylines: [
                    Polyline(
                        points: routeA,
                        color: Colors.blue,
                        strokeWidth: strokeA)
                  ],
                ),
              if (routeB.isNotEmpty)
                PolylineLayer(
                  polylines: [
                    Polyline(
                        points: routeB,
                        color: Colors.green,
                        strokeWidth: strokeB)
                  ],
                ),
              MarkerLayer(markers: markers),
            ],
          ),

          // PANEL SUPERIOR DERECHO: Reporte de Distancia Concisa
          Positioned(
            top: 16,
            right: 16,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (routeA.isNotEmpty && distanceA != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4.0),
                    child: GestureDetector(
                      onTap: () =>
                          setState(() => selectedRoute = RouteSelection.routeA),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(
                              selectedRoute == RouteSelection.routeA
                                  ? 1.0
                                  : 0.6),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                              color: selectedRoute == RouteSelection.routeA
                                  ? Colors.yellow
                                  : Colors.transparent,
                              width: 2),
                        ),
                        child: Text(
                            'Ruta A: ${_formatInfo(distanceA, null, includeTime: false)}',
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14)),
                      ),
                    ),
                  ),
                if (routeB.isNotEmpty && distanceB != null)
                  GestureDetector(
                    onTap: () =>
                        setState(() => selectedRoute = RouteSelection.routeB),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(
                            selectedRoute == RouteSelection.routeB ? 1.0 : 0.6),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                            color: selectedRoute == RouteSelection.routeB
                                ? Colors.yellow
                                : Colors.transparent,
                            width: 2),
                      ),
                      child: Text(
                          'Ruta B: ${_formatInfo(distanceB, null, includeTime: false)}',
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14)),
                    ),
                  ),
              ],
            ),
          ),

          // Indicador de carga
          if (loading)
            const Positioned(
              top: 16,
              left: 16,
              child: CircularProgressIndicator(),
            ),

          // Panel de Controles (Abajo Derecha)
          Positioned(
            bottom: 12,
            right: 12,
            child: Container(
              width: 260,
              constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.8),
              child: SingleChildScrollView(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            const Text('Modo:'),
                            const SizedBox(width: 8),
                            DropdownButton<StartMode>(
                              value: mode,
                              onChanged: (v) {
                                if (v == null) return;
                                setState(() {
                                  mode = v;
                                  if (mode == StartMode.gps) {
                                    _useGpsAsStart();
                                  }
                                });
                              },
                              items: const [
                                DropdownMenuItem(
                                  value: StartMode.manual,
                                  child: Text('Manual'),
                                ),
                                DropdownMenuItem(
                                  value: StartMode.gps,
                                  child: Text('GPS'),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Text('Coordenadas de inicio:'),
                        Row(
                          children: [
                            Flexible(
                              child: TextField(
                                  controller: startLatController,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                          decimal: true),
                                  decoration:
                                      const InputDecoration(labelText: 'Lat')),
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: TextField(
                                  controller: startLngController,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                          decimal: true),
                                  decoration:
                                      const InputDecoration(labelText: 'Lng')),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Text('Coordenadas de destino:'),
                        Row(
                          children: [
                            Flexible(
                              child: TextField(
                                  controller: endLatController,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                          decimal: true),
                                  decoration:
                                      const InputDecoration(labelText: 'Lat')),
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: TextField(
                                  controller: endLngController,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                          decimal: true),
                                  decoration:
                                      const InputDecoration(labelText: 'Lng')),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ElevatedButton(
                          onPressed: () {
                            final double? sLat =
                                double.tryParse(startLatController.text);
                            final double? sLng =
                                double.tryParse(startLngController.text);
                            final double? eLat =
                                double.tryParse(endLatController.text);
                            final double? eLng =
                                double.tryParse(endLngController.text);

                            if (sLat != null && sLng != null) {
                              startPoint = LatLng(sLat, sLng);
                            }
                            if (eLat != null && eLng != null) {
                              endPoint = LatLng(eLat, eLng);
                            }

                            if (startPoint != null && endPoint != null) {
                              _calculateRoutes();
                            }
                            setState(() {});
                          },
                          child: const Text('Calcular Ambas Rutas'),
                        ),
                        const SizedBox(height: 12),

                        const Text('Actualizar Individualmente:',
                            style: TextStyle(
                                fontSize: 12, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            ElevatedButton.icon(
                              onPressed:
                                  (startPoint != null && endPoint != null)
                                      ? _updateRouteA
                                      : null,
                              icon: const Icon(Icons.refresh,
                                  size: 14, color: Colors.blue),
                              label: const Text('Ruta A',
                                  style: TextStyle(
                                      fontSize: 10, color: Colors.blue)),
                            ),
                            ElevatedButton.icon(
                              onPressed:
                                  (startPoint != null && endPoint != null)
                                      ? _updateRouteB
                                      : null,
                              icon: const Icon(Icons.refresh,
                                  size: 14, color: Colors.green),
                              label: const Text('Ruta B',
                                  style: TextStyle(
                                      fontSize: 10, color: Colors.green)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Distancia y Tiempo en el panel de control (Formato Completo)
                        Text('Ruta A: $infoA',
                            style: TextStyle(
                                fontSize: 12,
                                color: selectedRoute == RouteSelection.routeA
                                    ? Colors.blue.shade900
                                    : Colors.blue)),
                        Text('Ruta B: $infoB',
                            style: TextStyle(
                                fontSize: 12,
                                color: selectedRoute == RouteSelection.routeB
                                    ? Colors.green.shade900
                                    : Colors.green)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          setState(() {
            startPoint = null;
            endPoint = null;
            startLatController.clear();
            startLngController.clear();
            endLatController.clear();
            endLngController.clear();
            _resetRouteInfo();
          });
        },
        icon: const Icon(Icons.delete_sweep),
        label: const Text('Resetear Mapa'),
      ),
    );
  }
}
