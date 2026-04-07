import 'package:flutter/material.dart';

class CustomTextField extends StatefulWidget {
  final String label;
  final IconData icon;
  final bool isPassword;
  final TextEditingController? controller;
  final TextInputType keyboardType;
  final String? Function(String?)? validator;

  const CustomTextField({
    Key? key,
    required this.label,
    required this.icon,
    this.isPassword = false,
    this.controller,
    this.keyboardType = TextInputType.text,
    this.validator,
  }) : super(key: key);

  @override
  State<CustomTextField> createState() => _CustomTextFieldState();
}

class _CustomTextFieldState extends State<CustomTextField> {
  late bool _obscureText;

  @override
  void initState() {
    super.initState();
    _obscureText = widget.isPassword;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: TextFormField(
        controller: widget.controller,
        obscureText: _obscureText,
        keyboardType: widget.keyboardType,
        validator: widget.validator,
        decoration: InputDecoration(
          labelText: widget.label,
          prefixIcon: Icon(widget.icon, color: Color(0xFFFF4009)),
          suffixIcon: widget.isPassword 
              ? IconButton(
                  icon: Icon(
                    _obscureText ? Icons.visibility_off : Icons.visibility,
                    color: Colors.grey,
                  ),
                  onPressed: () {
                    setState(() {
                      _obscureText = !_obscureText;
                    });
                  },
                )
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFFF4009), width: 2),
          ),
        ),
      ),
    );
  }
}
