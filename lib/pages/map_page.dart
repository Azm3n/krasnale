import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:ui' as ui;

import '../const/constants.dart';
import '../types/dwarf_atributes.dart';

class MapPage extends StatefulWidget {
  const MapPage({super.key});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  List<LatLng> polylineCoordinates = [];
  LocationData? currentLocation;
  Set<Marker> markers = {};
  BitmapDescriptor currentLocationIcon = BitmapDescriptor.defaultMarker;
  Map<String, DwarfAtributes> dwarfs = {
    "Krasnal Życzliwek": DwarfAtributes(51.11041199991326, 17.031257394620376, "zyczliwek.png"),
    "Krasnal Florianek": DwarfAtributes(51.106659310682, 17.031814202226073, "florianek.png")
  };

  void getCurrentLocation() {
    Location location = Location();

    location.getLocation().then((location) {
      currentLocation = location;
      markers.add(Marker(
        markerId: const MarkerId("currentLocation"),
        icon: currentLocationIcon,
        position: LatLng(currentLocation!.latitude!, currentLocation!.longitude!),
      ));
      setState(() {});
    });

    location.onLocationChanged.listen((event) {
      currentLocation = event;
      setState(() {});
    });
  }

  void getCurrentLocationIcon() async {
    final Uint8List markerIcon = await getBytesFromAsset('assets/better_monkey.png', 100);
    setState(() {
      currentLocationIcon = BitmapDescriptor.fromBytes(markerIcon);
    });
  }

  void getDwarfMarkers() {
    dwarfs.entries.forEach((dwarf) async {
      final Uint8List markerIcon = await getBytesFromAsset('assets/${dwarf.value.image}', 150);

      markers.add(
        Marker(
          markerId: MarkerId(dwarf.key),
          icon: BitmapDescriptor.fromBytes(markerIcon),
          position: LatLng(dwarf.value.latitude, dwarf.value.longitude),
        ),
      );
    });
    setState(() {});
  }

  Future<Uint8List> getBytesFromAsset(String path, int width) async {
    ByteData data = await rootBundle.load(path);
    ui.Codec codec = await ui.instantiateImageCodec(data.buffer.asUint8List(), targetWidth: width);
    ui.FrameInfo fi = await codec.getNextFrame();
    return (await fi.image.toByteData(format: ui.ImageByteFormat.png))!.buffer.asUint8List();
  }

  @override
  void initState() {
    getDwarfMarkers();
    getCurrentLocationIcon();
    getCurrentLocation();
    setPermissions();
    super.initState();
  }

  void setPermissions() async {
    await Permission.location.request();
  }

  void getPolyPoints(LatLng destination) async {
    PolylinePoints polylinePoints = PolylinePoints();
    try {
      PolylineResult result = await polylinePoints.getRouteBetweenCoordinates(
        Constants.API_KEY,
        PointLatLng(currentLocation!.latitude!, currentLocation!.longitude!),
        PointLatLng(destination.latitude, destination.longitude),
      );

      final List<LatLng> tmpCoordinates = [];
      if (result.points.isNotEmpty) {
        result.points.forEach(
          (PointLatLng point) => tmpCoordinates.add(
            LatLng(point.latitude, point.longitude),
          ),
        );
      }
      setState(() {
        polylineCoordinates = tmpCoordinates;
      });
    } catch (err) {
      print(err);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mapa'),
      ),
      body: currentLocation == null
          ? const Center(
              child: Text("Loading..."),
            )
          : Container(
              child: Column(
                children: [
                  Container(
                    height: 450,
                    child: GoogleMap(
                      initialCameraPosition: CameraPosition(
                        target: LatLng(currentLocation!.latitude!, currentLocation!.longitude!),
                        zoom: 15,
                      ),
                      polylines: {
                        Polyline(
                          polylineId: const PolylineId('route'),
                          points: polylineCoordinates,
                          color: Theme.of(context).colorScheme.primary,
                          width: 6,
                        ),
                      },
                      markers: markers,
                    ),
                  ),
                  Container(
                    height: 200,
                    child: ListView(
                      children: [
                        ...dwarfs.entries.map(
                          (dwarf) => InkWell(
                            onTap: () {
                              final destination = LatLng(dwarf.value.latitude, dwarf.value.longitude);

                              markers.add(Marker(
                                markerId: const MarkerId("currentLocation"),
                                icon: currentLocationIcon,
                                position: LatLng(currentLocation!.latitude!, currentLocation!.longitude!),
                              ));

                              getPolyPoints(destination);
                            },
                            child: Container(
                              decoration: BoxDecoration(border: Border.all(color: Colors.grey)),
                              margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.start,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Container(
                                    margin: const EdgeInsets.symmetric(horizontal: 10),
                                    child: CircleAvatar(
                                      backgroundColor: Theme.of(context).colorScheme.primary,
                                      backgroundImage: AssetImage(dwarf.value.image),
                                    ),
                                  ),
                                  Text(dwarf.key),
                                ],
                              ),
                            ),
                          ),
                        )
                      ],
                    ),
                  )
                ],
              ),
            ),
    );
  }
}
