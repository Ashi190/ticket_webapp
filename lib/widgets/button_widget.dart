import 'package:flutter/material.dart';

class ButtonWidget extends StatefulWidget {
  final String buttonText;
  final VoidCallback onPressed;
  final Color buttonColor;
  final Icon icon;
  final double buttonWidth;
  final double buttonHeight;

  const ButtonWidget({
    Key? key,
    required this.buttonText,
    required this.onPressed,
    required this.buttonColor,
    required this.icon,
    this.buttonWidth = 200, // Set default width
    this.buttonHeight = 46, // Set default height
  }) : super(key: key);

  @override
  State<ButtonWidget> createState() => _ButtonWidgetState();
}

class _ButtonWidgetState extends State<ButtonWidget> {
  bool _isHovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      child: GestureDetector(
        onTap: widget.onPressed,
        child: Container(
          width: widget.buttonWidth,
          height: widget.buttonHeight,
          decoration: BoxDecoration(
            color: _isHovering ? Colors.orangeAccent : widget.buttonColor, // Change color on hover
            borderRadius: BorderRadius.circular(12),
          ),
          padding: EdgeInsets.symmetric(vertical: 12, horizontal: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Adjusting alignment for better appearance
              widget.icon,
              SizedBox(width: 10),
              Expanded(  // Use Expanded to fill available space
                child: Text(
                  widget.buttonText,
                  textAlign: TextAlign.left, // Center align text
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}