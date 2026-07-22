import 'package:flutter/material.dart';
import '../../../core/theme/velox_colors.dart';
import '../../../core/theme/velox_spacing.dart';

/// Velox 输入框
class VeloxTextField extends StatelessWidget {
  final TextEditingController? controller;
  final String? hintText;
  final String? labelText;
  final bool obscureText;
  final TextInputType? keyboardType;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final String? Function(String?)? validator;
  final void Function(String)? onChanged;
  final void Function(String)? onSubmitted;
  final int? maxLines;
  final int? minLines;
  final bool enabled;
  final FocusNode? focusNode;
  final TextInputAction? textInputAction;

  const VeloxTextField({
    super.key,
    this.controller,
    this.hintText,
    this.labelText,
    this.obscureText = false,
    this.keyboardType,
    this.prefixIcon,
    this.suffixIcon,
    this.validator,
    this.onChanged,
    this.onSubmitted,
    this.maxLines = 1,
    this.minLines,
    this.enabled = true,
    this.focusNode,
    this.textInputAction,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (labelText != null) ...[
          Text(
            labelText!,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: VeloxColors.textSecondary,
            ),
          ),
          const SizedBox(height: VeloxSpacing.sm),
        ],
        TextFormField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          validator: validator,
          onChanged: onChanged,
          onFieldSubmitted: onSubmitted,
          maxLines: obscureText ? 1 : maxLines,
          minLines: minLines,
          enabled: enabled,
          focusNode: focusNode,
          textInputAction: textInputAction,
          style: const TextStyle(
            fontSize: 15,
            color: VeloxColors.textPrimary,
          ),
          decoration: InputDecoration(
            hintText: hintText,
            prefixIcon: prefixIcon,
            suffixIcon: suffixIcon,
            filled: true,
            fillColor: VeloxColors.bgCardWithOpacity(0.8),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: VeloxSpacing.lg,
              vertical: VeloxSpacing.lg,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(VeloxRadius.md),
              borderSide: BorderSide(
                color: VeloxColors.borderWithOpacity(0.5),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(VeloxRadius.md),
              borderSide: BorderSide(
                color: VeloxColors.borderWithOpacity(0.5),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(VeloxRadius.md),
              borderSide: const BorderSide(
                color: VeloxColors.primary,
                width: 2,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(VeloxRadius.md),
              borderSide: const BorderSide(
                color: VeloxColors.error,
              ),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(VeloxRadius.md),
              borderSide: const BorderSide(
                color: VeloxColors.error,
                width: 2,
              ),
            ),
            hintStyle: const TextStyle(
              color: VeloxColors.textTertiary,
              fontSize: 15,
            ),
          ),
        ),
      ],
    );
  }
}

/// Velox 验证码输入框
class VeloxCodeTextField extends StatelessWidget {
  final TextEditingController? controller;
  final String? hintText;
  final VoidCallback? onSendCode;
  final bool isSending;
  final int? countdown;
  final String? Function(String?)? validator;

  const VeloxCodeTextField({
    super.key,
    this.controller,
    this.hintText,
    this.onSendCode,
    this.isSending = false,
    this.countdown,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    final canSend = countdown == null || countdown == 0;

    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.number,
      validator: validator,
      style: const TextStyle(
        fontSize: 15,
        color: VeloxColors.textPrimary,
      ),
      decoration: InputDecoration(
        hintText: hintText,
        filled: true,
        fillColor: VeloxColors.bgCardWithOpacity(0.8),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: VeloxSpacing.lg,
          vertical: VeloxSpacing.lg,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(VeloxRadius.md),
          borderSide: BorderSide(
            color: VeloxColors.borderWithOpacity(0.5),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(VeloxRadius.md),
          borderSide: BorderSide(
            color: VeloxColors.borderWithOpacity(0.5),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(VeloxRadius.md),
          borderSide: const BorderSide(
            color: VeloxColors.primary,
            width: 2,
          ),
        ),
        hintStyle: const TextStyle(
          color: VeloxColors.textTertiary,
          fontSize: 15,
        ),
        suffixIcon: Padding(
          padding: const EdgeInsets.only(right: VeloxSpacing.sm),
          child: TextButton(
            onPressed: canSend && !isSending ? onSendCode : null,
            child: isSending
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(VeloxColors.primary),
                    ),
                  )
                : Text(
                    canSend ? '获取验证码' : '${countdown}s',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: canSend
                          ? VeloxColors.primary
                          : VeloxColors.textTertiary,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
