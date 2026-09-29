import 'package:flutter/material.dart';

class KupaLogo extends StatelessWidget {
  final double size;
  const KupaLogo({Key? key, this.size = 36}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2563EB), Color(0xFF10B981)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(size * 0.28),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF10B981).withOpacity(0.3),
            blurRadius: size * 0.25,
            offset: Offset(0, size * 0.1),
          ),
        ],
      ),
      child: Center(
        child: Icon(
          Icons.point_of_sale_rounded,
          color: Colors.white,
          size: size * 0.58,
        ),
      ),
    );
  }
}
