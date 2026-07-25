import 'dart:math' as math;

import 'package:an_do/features/sos/domain/sos_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:geolocator/geolocator.dart';

class CompassPage extends StatelessWidget {
  const CompassPage({required this.target, super.key});

  final SosSession target;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF061B22),
      body: SafeArea(
        child: StreamBuilder<CompassEvent>(
          stream: FlutterCompass.events,
          builder: (context, compassSnapshot) {
            final heading = compassSnapshot.data?.heading ?? 0;
            return FutureBuilder<Position>(
              future: Geolocator.getCurrentPosition(),
              builder: (context, positionSnapshot) {
                final position = positionSnapshot.data;
                final bearing = position == null
                    ? 0.0
                    : Geolocator.bearingBetween(
                        position.latitude,
                        position.longitude,
                        target.latitude,
                        target.longitude,
                      );
                final distance = position == null
                    ? 0.0
                    : Geolocator.distanceBetween(
                        position.latitude,
                        position.longitude,
                        target.latitude,
                        target.longitude,
                      );
                final rotation = (bearing - heading) * math.pi / 180;

                return Stack(
                  children: [
                    Positioned(
                      top: 8,
                      left: 8,
                      child: IconButton.filledTonal(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close),
                      ),
                    ),
                    Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'HƯỚNG TỚI NGƯỜI CẦN CỨU',
                            style: TextStyle(
                              color: Colors.white70,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1,
                            ),
                          ),
                          const SizedBox(height: 30),
                          Container(
                            width: 280,
                            height: 280,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white24),
                            ),
                            child: Transform.rotate(
                              angle: rotation,
                              child: const Icon(
                                Icons.navigation_rounded,
                                size: 150,
                                color: Color(0xFFFF626A),
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            '${bearing.round()}°',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 40,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          Text(
                            '${distance.round()} m · SOS ${target.id}',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}
