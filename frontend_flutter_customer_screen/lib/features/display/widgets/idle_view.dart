import 'package:flutter/material.dart';

/// Shown while there is no active cart — a simple welcome/branding screen.
class IdleView extends StatelessWidget {
  const IdleView({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF1B1F23),
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.storefront, size: 96, color: Colors.white70),
            SizedBox(height: 24),
            Text(
              'Welcome!',
              style: TextStyle(
                color: Colors.white,
                fontSize: 40,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
