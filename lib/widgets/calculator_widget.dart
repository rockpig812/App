import 'package:flutter/material.dart';

class CalculatorWidget extends StatefulWidget {
  final Function(double value) onSubmitted;
  final Function(String displayString) onChanged;

  const CalculatorWidget({
    super.key,
    required this.onSubmitted,
    required this.onChanged,
  });

  @override
  State<CalculatorWidget> createState() => _CalculatorWidgetState();
}

class _CalculatorWidgetState extends State<CalculatorWidget> {
  String _displayText = "0";

  void _onNumberPress(String val) {
    setState(() {
      if (_displayText == "0") {
        _displayText = val;
      } else {
        if (_displayText.length < 12) {
          _displayText += val;
        }
      }
      widget.onChanged(_displayText);
    });
  }

  void _onDotPress() {
    setState(() {
      if (!_displayText.contains('.')) {
        _displayText += '.';
        widget.onChanged(_displayText);
      }
    });
  }

  void _onAC() {
    setState(() {
      _displayText = "0";
      widget.onChanged(_displayText);
    });
  }

  void _onDelete() {
    setState(() {
      if (_displayText.length > 1) {
        _displayText = _displayText.substring(0, _displayText.length - 1);
      } else {
        _displayText = "0";
      }
      widget.onChanged(_displayText);
    });
  }

  void _onOK() {
    final finalValue = double.tryParse(_displayText) ?? 0;
    widget.onSubmitted(finalValue);
  }

  @override
  Widget build(BuildContext context) {
    final secondaryColor = Colors.amber.shade400;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      decoration: BoxDecoration(
        color: secondaryColor.withOpacity(0.1),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: IntrinsicHeight( // 確保左右兩邊等高
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              flex: 4,
              child: Column(
                children: [
                  _buildRow(["7", "8", "9"]),
                  const SizedBox(height: 12),
                  _buildRow(["4", "5", "6"]),
                  const SizedBox(height: 12),
                  _buildRow(["1", "2", "3"]),
                  const SizedBox(height: 12),
                  _buildRow(["AC", "0", "."]),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 1,
              child: Column(
                children: [
                  _buildSideButton(const Icon(Icons.backspace_outlined, size: 24), _onDelete, Colors.grey.shade200),
                  const SizedBox(height: 12),
                  // OK 按鈕現在佔據剩餘所有空間，但在 IntrinsicHeight 下是安全的
                  Expanded(child: _buildOKButton()),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRow(List<String> labels) {
    return Row(
      children: labels.map((label) {
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: _buildNumberButton(label),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildNumberButton(String label) {
    return AspectRatio(
      aspectRatio: 1.5,
      child: ElevatedButton(
        onPressed: () {
          if (label == "AC") {
            _onAC();
          } else if (label == ".") {
            _onDotPress();
          } else {
            _onNumberPress(label);
          }
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black87,
          elevation: 2,
          shadowColor: Colors.black.withOpacity(0.1),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          padding: EdgeInsets.zero,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 22,
            fontWeight: label == "AC" ? FontWeight.bold : FontWeight.w600,
            color: label == "AC" ? Colors.orange : Colors.black87,
          ),
        ),
      ),
    );
  }

  Widget _buildSideButton(Widget content, VoidCallback onPressed, Color color) {
    return AspectRatio(
      aspectRatio: 1.5, // 與數字鍵保持一致
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.black87,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          padding: EdgeInsets.zero,
        ),
        child: content,
      ),
    );
  }

  Widget _buildOKButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _onOK,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.orange,
          foregroundColor: Colors.white,
          elevation: 4,
          shadowColor: Colors.orange.withOpacity(0.4),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          padding: EdgeInsets.zero,
        ),
        child: const Text(
          "OK",
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
