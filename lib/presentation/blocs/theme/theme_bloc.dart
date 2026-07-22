import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'theme_event.dart';
part 'theme_state.dart';

/// Velox is the app's sole theme. `ThemeBloc` only tracks light/dark/system
/// for future flexibility — the classic "Velox" skin has been retired.
class ThemeBloc extends Bloc<ThemeEvent, ThemeState> {
  static const String _themeKey = 'app_theme_mode';

  ThemeBloc() : super(const ThemeState()) {
    on<ThemeInitialized>(_onInitialized);
    on<ThemeChanged>(_onChanged);
  }

  Future<void> _onInitialized(
    ThemeInitialized event,
    Emitter<ThemeState> emit,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final themeIndex = prefs.getInt(_themeKey) ?? 1; // default: light
    emit(state.copyWith(themeMode: ThemeMode.values[themeIndex]));
  }

  Future<void> _onChanged(
    ThemeChanged event,
    Emitter<ThemeState> emit,
  ) async {
    emit(state.copyWith(themeMode: event.themeMode));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_themeKey, event.themeMode.index);
  }
}
