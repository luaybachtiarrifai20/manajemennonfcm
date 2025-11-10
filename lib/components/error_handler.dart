// error_handler.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class AppErrorHandler {
  static final AppErrorHandler _instance = AppErrorHandler._internal();
  factory AppErrorHandler() => _instance;
  AppErrorHandler._internal();

  static final StreamController<Exception> _errorController = 
      StreamController<Exception>.broadcast();
  static Stream<Exception> get errorStream => _errorController.stream;

  static void setupErrorHandling() {
    // Handle Flutter errors
    FlutterError.onError = (FlutterErrorDetails details) {
      if (kDebugMode) {
        FlutterError.presentError(details);
      }
      
      // Kirim error ke stream
      _errorController.add(Exception(details.exception.toString()));
      
      // Log error
      _logError('Flutter Error', details.exception, details.stack);
    };

    // Handle Dart errors
    PlatformDispatcher.instance.onError = (error, stack) {
      if (kDebugMode) {
        print('Dart Error: $error');
        print('Stack: $stack');
      }
      
      // Kirim error ke stream
      _errorController.add(Exception(error.toString()));
      
      // Log error
      _logError('Dart Error', error, stack);
      
      return true;
    };
  }

  static void _logError(String type, dynamic error, StackTrace? stack) {
    if (kDebugMode) {
      print('$type: $error');
      if (stack != null) {
        print('Stack: $stack');
      }
    }
  }

  static void dispose() {
    _errorController.close();
  }
}