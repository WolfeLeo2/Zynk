import 'package:flutter/material.dart';

import '../../core/theme/app_tokens.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

class DesignSystemGalleryPage extends StatelessWidget {
  const DesignSystemGalleryPage({super.key});

  @override
  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Zynk Design System v2.0'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Tokens & Components'),
              Tab(text: 'POS Sandbox'),
            ],
          ),
        ),
        body: const TabBarView(children: [_TokensTab(), _PosSandboxTab()]),
      ),
    );
  }
}

class _PosSandboxTab extends StatelessWidget {
  const _PosSandboxTab();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.surface,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'POS Components Sandbox',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 16),
          // TODO: Add PosProductCard here
          Container(
            height: 100,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Theme.of(context).colorScheme.outline),
            ),
            alignment: Alignment.center,
            child: const Text('Comming Soon: PosProductCard'),
          ),
          const SizedBox(height: 16),
          // TODO: Add PosTicket here
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outline,
                ),
              ),
              alignment: Alignment.center,
              child: const Text('Comming Soon: PosTicket (Cart)'),
            ),
          ),
        ],
      ),
    );
  }
}

class _TokensTab extends StatelessWidget {
  const _TokensTab();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // 1. Typography Section
        _SectionHeader(title: '1. Typography (Clash Display & Outfit)'),
        const SizedBox(height: 16),
        Text('Display Large', style: theme.textTheme.displayLarge),
        Text('Headline Medium', style: theme.textTheme.headlineMedium),
        Text('Title Large', style: theme.textTheme.titleLarge),
        Text('Body Medium', style: theme.textTheme.bodyMedium),
        const SizedBox(height: 16),
        Text(
          'The quick brown fox jumps over the lazy dog. 1234567890',
          style: theme.textTheme.bodyLarge,
        ),

        const Divider(height: 48),

        // 2. Buttons & Interactions
        _SectionHeader(title: '2. Buttons & Interactions (Squishy?)'),
        const SizedBox(height: 16),
        Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            ElevatedButton(
              onPressed: () {},
              child: const Text('Primary Action'),
            ),
            ElevatedButton.icon(
              onPressed: () {},
              icon: PhosphorIcon(PhosphorIconsDuotone.lightning),
              label: const Text('With Icon'),
            ),
            OutlinedButton(
              onPressed: () {},
              child: const Text('Secondary Action'),
            ),
          ],
        ),

        const Divider(height: 48),

        // 3. Cards & Surfaces
        _SectionHeader(title: '3. Cards & Surfaces'),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.secondary,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: PhosphorIcon(
                        PhosphorIconsDuotone.archive,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Inventory Alert',
                          style: theme.textTheme.titleMedium,
                        ),
                        Text(
                          'Low stock on 3 items',
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  'This card uses the new generic CardTheme with correct borders and shadows.',
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ),

        const Divider(height: 48),

        // 4. Inputs
        _SectionHeader(title: '4. Inputs & Forms'),
        const SizedBox(height: 16),
        const TextField(
          decoration: InputDecoration(
            labelText: 'Email Address',
            hintText: 'name@example.com',
            prefixIcon: PhosphorIcon(PhosphorIconsDuotone.envelope),
          ),
        ),
        const SizedBox(height: 16),
        const TextField(
          decoration: InputDecoration(
            labelText: 'Password',
            suffixIcon: PhosphorIcon(PhosphorIconsDuotone.eye),
          ),
          obscureText: true,
        ),

        const Divider(height: 48),

        // 5. Colors
        _SectionHeader(title: '5. Semantic Palette'),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          children: [
            _ColorChip(
              color: Theme.of(context).colorScheme.primary,
              label: 'Primary',
            ),
            _ColorChip(
              color: Theme.of(context).colorScheme.secondary,
              label: 'Secondary',
            ),
            _ColorChip(color: AppTokens.brandAccent, label: 'Accent'),
            _ColorChip(
              color: Theme.of(context).colorScheme.surface,
              label: 'Canvas',
            ),
            _ColorChip(
              color: Theme.of(context).colorScheme.surface,
              label: 'Surface+',
            ),
          ],
        ),

        const SizedBox(height: 100),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
        color: Theme.of(context).colorScheme.secondary,
        letterSpacing: 1.2,
        fontWeight: FontWeight.bold,
      ),
    );
  }
}

class _ColorChip extends StatelessWidget {
  final Color color;
  final String label;
  const _ColorChip({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white24, width: 1),
          ),
        ),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(fontSize: 10)),
      ],
    );
  }
}
