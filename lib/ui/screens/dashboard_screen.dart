import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models.dart';
import '../theme/theme.dart';
import 'editor_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  static const platform = MethodChannel('com.example.lowcode/widget');
  List<dynamic> _widgets = [];
  bool _loading = true;
  bool _isDragging = false;

  @override
  void initState() {
    super.initState();
    _fetchWidgets();
    platform.setMethodCallHandler((call) async {
      if (call.method == 'navigateToEditor') {
         // Received request to open editor (e.g. from Widget Click)
         // Check if we are already in editor? For now just push.
         if (mounted) {
             debugPrint("Native requested editor navigation");
             _openEditor(null); // Open for NEW logic
         }
      }
    });
  }

  Future<void> _fetchWidgets() async {
    setState(() => _loading = true);
    try {
      final List<dynamic> result = await platform.invokeMethod('getAllWidgets');
      setState(() {
        _widgets = result;
        _loading = false;
      });
    } on PlatformException catch (e) {
      debugPrint("Failed to fetch widgets: '${e.message}'.");
      setState(() => _loading = false);
    }
  }

  Future<void> _pinWidget(int widgetId) async {
      try {
          await platform.invokeMethod('pinWidget', {'widgetId': widgetId});
      } on PlatformException catch (e) {
          debugPrint("Failed to pin: ${e.message}");
          if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Pin Failed: ${e.message}")));
          }
      }
  }

  Future<void> _deleteWidget(int widgetId) async {
    try {
        await platform.invokeMethod('deleteWidget', {'widgetId': widgetId});
        _fetchWidgets();
        if (mounted) {
             ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Widget deleted")));
        }
    } on PlatformException catch (e) {
        debugPrint("Failed to delete: ${e.message}");
    }
  }

  Future<void> _nukeDb() async {
      await platform.invokeMethod('clearAllWidgets');
      _fetchWidgets();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Database Cleared")));
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      appBar: AppBar(
        title: const Text('Dashboard', style: AppStyles.headerStyle),
        backgroundColor: AppColors.cardBg,
        elevation: 0,
        centerTitle: false,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.white,
          statusBarIconBrightness: Brightness.dark,
          statusBarBrightness: Brightness.light,
        ),
        actions: [
            IconButton(
                icon: const Icon(Icons.delete_forever, color: Colors.red),
                tooltip: "Clear All (Debug)",
                onPressed: _nukeDb,
            )
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: AppColors.border, height: 1),
        ),
      ),
      body: Stack(
          children: [
              _loading 
                  ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                  : _widgets.isEmpty 
                      ? _buildEmptyState()
                      : GridView.builder(
                          padding: const EdgeInsets.all(16),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 3, // Changed from 4 to 3
                              crossAxisSpacing: 16,
                              mainAxisSpacing: 16,
                              childAspectRatio: 0.85, 
                          ),
                          itemCount: _widgets.length,
                          itemBuilder: (context, index) {
                            final w = _widgets[index];
                            return _DraggableWidgetGridItem(
                              data: w, 
                              onTap: () => _openEditor(w['widgetId']),
                              onPin: () => _pinWidget(w['widgetId']),
                              onDragStarted: () => setState(() => _isDragging = true),
                              onDragEnd: () => setState(() => _isDragging = false),
                            );
                          },
                        ),
              
              // Trash Bin Overlay
              if (_isDragging)
                Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    height: 80, // Reduced from 100
                    child: DragTarget<int>(
                        onAccept: (widgetId) {
                            _deleteWidget(widgetId);
                            setState(() => _isDragging = false);
                        },
                        builder: (context, candidates, rejects) {
                            final isHovering = candidates.isNotEmpty;
                            return Container(
                                decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                        colors: isHovering 
                                            ? [Colors.red.withOpacity(0.0), Colors.red.withOpacity(0.3)] // Subtle hover
                                            : [Colors.red.withOpacity(0.0), Colors.red.withOpacity(0.1)], // Micro red normal
                                    ),
                                ),
                                alignment: Alignment.center,
                                child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                        Icon(Icons.delete_outline, 
                                            color: isHovering ? Colors.red : Colors.red.withOpacity(0.5), 
                                            size: 32
                                        ),
                                        if (isHovering) 
                                            const Text("Release to Delete", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold))
                                    ],
                                ),
                            );
                        },
                    ),
                ),
          ],
      ),
      floatingActionButton: _isDragging ? null : FloatingActionButton(
        backgroundColor: AppColors.primary,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
        onPressed: () => _openEditor(null), 
        child: const Icon(Icons.add),
      ),
    );
  }
  
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.dashboard_customize_outlined, size: 48, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          const Text("No widgets deployed", style: TextStyle(color: AppColors.textBody)),
          const SizedBox(height: 4),
          const Text("Click + to deploy a new server logic", style: TextStyle(color: AppColors.textBody, fontSize: 12)),
        ],
      ),
    );
  }

  Future<void> _openEditor(int? widgetId) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => EditorScreen(widgetId: widgetId)),
    );
    if (result == true) {
      _fetchWidgets(); 
    }
  }
}

class _DraggableWidgetGridItem extends StatelessWidget {
  final Map<dynamic, dynamic> data;
  final VoidCallback onTap;
  final VoidCallback onPin;
  final VoidCallback onDragStarted;
  final VoidCallback onDragEnd;

  const _DraggableWidgetGridItem({
      required this.data, 
      required this.onTap, 
      required this.onPin,
      required this.onDragStarted,
      required this.onDragEnd,
  });

  @override
  Widget build(BuildContext context) {
    final widgetId = data['widgetId'] as int;
    
    return LongPressDraggable<int>(
        data: widgetId,
        onDragStarted: onDragStarted,
        onDraggableCanceled: (_, __) => onDragEnd(),
        onDragEnd: (_) => onDragEnd(),
        feedback: Material(
            color: Colors.transparent,
            child: _WidgetGridItemContent(data: data, onPin: null, isFeedback: true),
        ),
        childWhenDragging: Opacity(
            opacity: 0.3, 
            child: _WidgetGridItemContent(data: data, onPin: onPin),
        ),
        child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: _WidgetGridItemContent(data: data, onPin: onPin),
        ),
    );
  }
}

class _WidgetGridItemContent extends StatelessWidget {
    final Map<dynamic, dynamic> data;
    final VoidCallback? onPin;
    final bool isFeedback;
    
    const _WidgetGridItemContent({required this.data, this.onPin, this.isFeedback = false});
    
    @override
    Widget build(BuildContext context) {
        final iconId = data['iconId'] as String? ?? 'TERMINAL';
        final iconData = IconMap.icons[iconId] ?? Icons.help_outline;
        final label = data['label'] as String? ?? 'Unknown';
        
        return Stack(
          alignment: Alignment.center,
          children: [
             Column(
                 mainAxisSize: MainAxisSize.min,
                 children: [
                     Container(
                         width: 64, // Increased size from 48
                         height: 64, // Increased size from 48
                         padding: const EdgeInsets.all(3),
                         decoration: BoxDecoration(
                             color: Colors.white,
                             borderRadius: BorderRadius.circular(16), // Increased radius
                             border: Border.all(color: const Color(0xFFE0E0E0), width: 0.5),
                             boxShadow: isFeedback ? [BoxShadow(color: Colors.black26, blurRadius: 10)] : [],
                         ),
                         child: Container(
                             decoration: const BoxDecoration(
                                 shape: BoxShape.circle,
                                 gradient: LinearGradient(
                                     colors: [Color(0xFF00C6FB), Color(0xFF005BEA)],
                                     begin: Alignment.topLeft,
                                     end: Alignment.bottomRight,
                                 ),
                             ),
                             child: Stack(
                                 alignment: Alignment.center,
                                 children: [
                                     // Static Ring
                                     Padding(
                                         padding: const EdgeInsets.all(1.5), // Scaled padding slightly
                                         child: SizedBox.expand(
                                             child: CircularProgressIndicator(
                                                 value: 1.0,
                                                 strokeWidth: 5.5, // Thicker ring for larger size
                                                 valueColor: AlwaysStoppedAnimation(Colors.white.withOpacity(0.55)),
                                             ),
                                         ),
                                     ),
                                     // Icon
                                     Icon(iconData, color: Colors.white, size: 32), // Scaled icon size
                                 ],
                             ),
                         ),
                     ),
                     const SizedBox(height: 6),
                     Text(label, 
                         style: const TextStyle(fontSize: 11, color: AppColors.textHeader),
                         maxLines: 1,
                         overflow: TextOverflow.ellipsis,
                         textAlign: TextAlign.center,
                     ),
                 ],
             ),
             
             if (onPin != null)
                 Positioned(
                     top: 0,
                     right: 0,
                     child: InkWell(
                         onTap: onPin,
                         child: Container(
                             padding: const EdgeInsets.all(4),
                             decoration: const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 2)]
                             ),
                             child: const Icon(Icons.add_circle, size: 14, color: AppColors.textBody),
                         ),
                     ),
                 )
          ],
        );
    }
}
