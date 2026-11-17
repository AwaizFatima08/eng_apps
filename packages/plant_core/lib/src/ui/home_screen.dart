import 'package:flutter/material.dart';

import '../settings.dart';
import '../tool.dart';
import 'info_screens.dart';
import 'tool_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _query = '';

  bool _matches(ToolDef t) {
    if (_query.isEmpty) return true;
    final hay = [t.title, t.summary, ...t.keywords].join(' ').toLowerCase();
    return _query.toLowerCase().split(RegExp(r'\s+')).every(hay.contains);
  }

  @override
  Widget build(BuildContext context) {
    final config = ConfigScope.of(context);
    final tools = config.tools.where(_matches).toList();
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(config.appName),
            Text(
              config.discipline,
              style: Theme.of(
                context,
              ).textTheme.labelMedium?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Settings',
            icon: const Icon(Icons.tune),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
          IconButton(
            tooltip: 'About',
            icon: const Icon(Icons.info_outline),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AboutScreen()),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: SearchBar(
                hintText: 'Search tools',
                leading: const Icon(Icons.search),
                elevation: const WidgetStatePropertyAll(0),
                onChanged: (q) => setState(() => _query = q.trim()),
              ),
            ),
            Expanded(
              child: tools.isEmpty
                  ? const Center(child: Text('No tool matches your search'))
                  : LayoutBuilder(
                      builder: (context, box) {
                        // Two tiles per row on phones, more on tablets.
                        final cols = (box.maxWidth / 280).floor().clamp(2, 4);
                        final rows = (tools.length / cols).ceil();
                        return ListView.builder(
                          padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
                          itemCount: rows,
                          itemBuilder: (context, r) => IntrinsicHeight(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                for (var c = 0; c < cols; c++)
                                  Expanded(
                                    child: r * cols + c < tools.length
                                        ? _ToolTile(tool: tools[r * cols + c])
                                        : const SizedBox.shrink(),
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One tool on the home grid: icon, name and a short summary. Rows size to
/// their tallest tile, so long names at large font sizes never get cut off.
class _ToolTile extends StatelessWidget {
  const _ToolTile({required this.tool});

  final ToolDef tool;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Card(
      margin: const EdgeInsets.all(4),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => ToolScreen(tool: tool)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: scheme.primaryContainer,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(tool.icon, color: scheme.onPrimaryContainer),
              ),
              const SizedBox(height: 12),
              Text(
                tool.title,
                style: text.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(
                tool.summary,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
