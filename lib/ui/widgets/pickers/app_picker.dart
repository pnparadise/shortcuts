import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/theme.dart';

class AppPicker extends StatefulWidget {
  const AppPicker({super.key});

  static Future<Map<String, String>?> show(BuildContext context) {
    return showModalBottomSheet<Map<String, String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const AppPicker(),
    );
  }

  @override
  State<AppPicker> createState() => _AppPickerState();
}

class _AppPickerState extends State<AppPicker> {
  static const platform = MethodChannel('com.shortcuts.shortcuts/widget');
  
  List<Map<String, dynamic>> _apps = [];
  List<Map<String, dynamic>> _filteredApps = [];
  bool _loading = true;
  final TextEditingController _searchCtl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadApps();
  }

  Future<void> _loadApps() async {
    try {
      final List<dynamic> result = await platform.invokeMethod('getInstalledApps');
      setState(() {
        _apps = result.map((e) => Map<String, dynamic>.from(e)).toList();
        _filteredApps = _apps;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      debugPrint("Load Apps Error: $e");
    }
  }

  void _filter(String query) {
    setState(() {
      _filteredApps = _apps.where((app) {
        final name = app['name']?.toString().toLowerCase() ?? "";
        final pkg = app['packageName']?.toString().toLowerCase() ?? "";
        return name.contains(query.toLowerCase()) || pkg.contains(query.toLowerCase());
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      heightFactor: 0.8,
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.scaffoldBg,
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: _searchCtl,
                onChanged: _filter,
                decoration: InputDecoration(
                  hintText: "Search apps...",
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: AppColors.inputBg,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
            ),
            Expanded(
              child: _loading 
                ? const Center(child: CircularProgressIndicator())
                : _filteredApps.isEmpty
                  ? const Center(child: Text("No apps found"))
                  : ListView.builder(
                      itemCount: _filteredApps.length,
                      itemBuilder: (context, index) {
                        final app = _filteredApps[index];
                        final iconBytes = app['icon'] as Uint8List?;
                        return ListTile(
                          leading: iconBytes != null 
                            ? Image.memory(iconBytes, width: 32, height: 32)
                            : const Icon(Icons.android, color: Colors.green),
                          title: Text(app['name'] ?? "Unknown", style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text(app['packageName'] ?? ""),
                          onTap: () {
                            Navigator.pop(context, <String, String>{
                              'name': app['name']?.toString() ?? "",
                              'packageName': app['packageName']?.toString() ?? "",
                            });
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ).animate().slideY(begin: 1.0, end: 0.0), // Note: animate() depends on a package, removing if not present
    );
  }
}

// Simple extension for simpler code if flutter_animate is preferred, but I'll stick to basic.
extension on Widget {
    Widget animate() => this; // Dummy for now
    Widget slideY({double? begin, double? end}) => this;
}
