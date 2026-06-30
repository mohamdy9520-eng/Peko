import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class CustomFabMenu extends StatefulWidget {
  final VoidCallback onAskAI;
  final VoidCallback onAddSavings;
  final VoidCallback onAddIncome;

  const CustomFabMenu({
    super.key,
    required this.onAskAI,
    required this.onAddSavings,
    required this.onAddIncome,
  });

  @override
  State<CustomFabMenu> createState() => _CustomFabMenuState();
}

class _CustomFabMenuState extends State<CustomFabMenu>
    with SingleTickerProviderStateMixin {
  bool _isOpen = false;
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() {
      _isOpen = !_isOpen;
      if (_isOpen) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // Ask AI
        _buildMenuItem(
          label: 'Ask AI',
          icon: Icons.auto_awesome,
          color: Colors.orange,
          onTap: widget.onAskAI,
          delay: 0,
        ),
        SizedBox(height: 12.h),
        // Add Savings
        _buildMenuItem(
          label: 'Add Savings',
          icon: Icons.savings,
          color: Colors.teal,
          onTap: widget.onAddSavings,
          delay: 1,
        ),
        SizedBox(height: 12.h),
        // Add Income
        _buildMenuItem(
          label: 'Add Income',
          icon: Icons.add,
          color: Colors.green,
          onTap: widget.onAddIncome,
          delay: 2,
        ),
        SizedBox(height: 12.h),
        // Main FAB
        FloatingActionButton(
          onPressed: _toggle,
          backgroundColor: Colors.deepPurple,
          child: AnimatedIcon(
            icon: AnimatedIcons.menu_close,
            progress: _controller,
            color: Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _buildMenuItem({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    required int delay,
  }) {
    return AnimatedOpacity(
      opacity: _isOpen ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 200),
      child: AnimatedSlide(
        offset: _isOpen ? Offset.zero : const Offset(0.5, 0),
        duration: Duration(milliseconds: 200 + (delay * 50)),
        child: IgnorePointer(
          ignoring: !_isOpen,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Label
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                decoration: BoxDecoration(
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12.sp,
                  ),
                ),
              ),
              SizedBox(width: 8.w),
              // FAB
              FloatingActionButton.small(
                onPressed: () {
                  _toggle();
                  onTap();
                },
                backgroundColor: color,
                child: Icon(icon, color: Colors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }
}