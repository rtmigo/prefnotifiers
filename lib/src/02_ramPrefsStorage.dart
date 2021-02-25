// Copyright (c) 2021 Artёm Galkin.
// Use of this source code is governed by a MIT license.
// See LICENSE file for details

import '01_prefsStorage.dart';

/// A [PrefsStorage] that keeps all the data in RAM only. Useful for testing.
class RamPrefsStorage extends PrefsStorage
{
  Map<String,dynamic> _data = Map<String,dynamic>();

  Future<String> getString(String key) async => _data[key];
  Future<bool> getBool(String key) async => _data[key];
  Future<int> getInt(String key) async => _data[key];
  Future<double> getDouble(String key) => _data[key];
  Future<List<String>> getStringList(String key) async => _data[key];

  Future<void> setString(String key, String value) async => _data[key] = value;
  Future<void> setDouble(String key, double value) async => _data[key] = value;
  Future<void> setInt(String key, int value) async => _data[key] = value;
  Future<void> setBool(String key, bool value) async => _data[key] = value;
  Future<void> setStringList(String key, List<String> value) async => _data[key] = value;

  Future<Set<String>> getKeys(String key) async => Set<String>.from(_data.values);
}