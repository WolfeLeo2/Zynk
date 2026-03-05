import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

class AuthPinPad extends StatelessWidget {
  final VoidCallback? onBiometricTap;
  final Function(int) onNumberTap;
  final VoidCallback onDeleteTap;
  final bool showBiometricIcon;

  const AuthPinPad({
    super.key,
    this.onBiometricTap,
    required this.onNumberTap,
    required this.onDeleteTap,
    this.showBiometricIcon = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildDialPadButton(context, '1', () => onNumberTap(1)),
            _buildDialPadButton(context, '2', () => onNumberTap(2)),
            _buildDialPadButton(context, '3', () => onNumberTap(3)),
          ],
        ),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildDialPadButton(context, '4', () => onNumberTap(4)),
            _buildDialPadButton(context, '5', () => onNumberTap(5)),
            _buildDialPadButton(context, '6', () => onNumberTap(6)),
          ],
        ),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildDialPadButton(context, '7', () => onNumberTap(7)),
            _buildDialPadButton(context, '8', () => onNumberTap(8)),
            _buildDialPadButton(context, '9', () => onNumberTap(9)),
          ],
        ),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            if (showBiometricIcon)
              _buildDialPadIcon(
                context,
                PhosphorIconsDuotone.fingerprint,
                onBiometricTap ?? () {},
              )
            else
              const SizedBox(width: 72, height: 72),
            _buildDialPadButton(context, '0', () => onNumberTap(0)),
            _buildDialPadIcon(
              context,
              PhosphorIconsDuotone.backspace,
              onDeleteTap,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDialPadButton(
    BuildContext context,
    String text,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
        ),
        alignment: Alignment.center,
        child: Text(
          text,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ),
    );
  }

  Widget _buildDialPadIcon(
    BuildContext context,
    IconData icon,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 72,
        height: 72,
        alignment: Alignment.center,
        child: PhosphorIcon(
          icon,
          size: 28,
          color: Theme.of(context).colorScheme.onSurface,
        ),
      ),
    );
  }
}
