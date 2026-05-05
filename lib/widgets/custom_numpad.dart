import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class CustomNumpad extends StatelessWidget {
  final Function(String) onNumberPressed;
  final VoidCallback onDeletePressed;

  const CustomNumpad({
    super.key,
    required this.onNumberPressed,
    required this.onDeletePressed,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.5,
      padding: const EdgeInsets.all(16),
      children: [
        _buildButton('1'),
        _buildButton('2'),
        _buildButton('3'),
        _buildButton('4'),
        _buildButton('5'),
        _buildButton('6'),
        _buildButton('7'),
        _buildButton('8'),
        _buildButton('9'),
        _buildButton('.'),
        _buildButton('0'),
        _buildDeleteButton(),
      ],
    );
  }

  Widget _buildButton(String text) {
    return InkWell(
      onTap: () => onNumberPressed(text),
      borderRadius: BorderRadius.circular(16),
      child: Center(
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w500,
            color: AppColors.textPrimary,
          ),
        ),
      ),
    );
  }

  Widget _buildDeleteButton() {
    return InkWell(
      onTap: onDeletePressed,
      borderRadius: BorderRadius.circular(16),
      child: const Center(
        child: Icon(
          Icons.backspace_outlined,
          color: AppColors.textPrimary,
          size: 28,
        ),
      ),
    );
  }
}
