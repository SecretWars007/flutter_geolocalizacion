# flutter_geolocalizacion (Mi Ruta de Escape)

Proyecto Flutter de ejemplo que muestra dos rutas entre un punto inicial y uno final con OpenStreetMap y OSRM.
Incluye:
- Splash screen con logo caricaturesco (taxi escapando de trancadera).
- Selector de modo: GPS o Manual (tap en mapa).
- Dibuja dos rutas (OSRM alternatives=true) con iconos de taxi y colores diferentes.
- Configuración con flutter_dotenv (.env.example incluido).

Instrucciones rápidas:
1. Descomprime el ZIP.
2. `cd flutter_geolocalizacion`
3. `flutter pub get`
4. Copia `.env.example` a `.env.private` y ajusta si lo necesitas.
5. `flutter run`