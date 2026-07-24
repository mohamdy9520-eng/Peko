import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';

class NetworkProvider extends ChangeNotifier {
  bool _isConnected = true;
  bool get isConnected => _isConnected;

  bool _wasDisconnected = false;
  bool get wasDisconnected => _wasDisconnected;

  NetworkProvider() {
    _init();
  }

  void _init() {
    Connectivity().checkConnectivity().then((result) {
      _updateConnection(result != ConnectivityResult.none);
    });

    Connectivity().onConnectivityChanged.listen((result) {
      final connected = result != ConnectivityResult.none;
      _updateConnection(connected);
    });
  }

  void _updateConnection(bool connected) {
    if (_isConnected != connected) {
      _wasDisconnected = !connected;
      _isConnected = connected;
      notifyListeners();
    }
  }
}