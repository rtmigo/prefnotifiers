// Copyright (c) 2021 Artyom Galkin
// 
// Use of this source code is governed by a MIT license:
// 
// Permission is hereby granted, free of charge, to any person obtaining a
// copy of this software and associated documentation files (the "Software"),
// to deal in the Software without restriction, including without limitation
// the rights to use, copy, modify, merge, publish, distribute, sublicense,
// and/or sell copies of the Software, and to permit persons to whom the
// Software is furnished to do so, subject to the following conditions:
// 
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
// 
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
// THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
// FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
// DEALINGS IN THE SOFTWARE.


import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:prefnotifiers/src/00_global.dart';

import '01_prefsStorage.dart';
import '10_awaitableCalls.dart';

class PrefItemNotFoundError implements Exception {}
class PrefItemNotInitializedError implements Exception {}

typedef CheckValueFunc<T>(T val);
typedef T AdjustFunc<T>(T old);

/// Represents a particular named value in a [PrefsStorage].
///
/// The [value] property acts like a synchronous "cache", while real reading and writing
/// is done asynchronously in background.
///
/// For a newly created object the [value] always returns [null], since the data is not read yet.
class PrefItem<T> extends ChangeNotifier implements ValueNotifier<T>
{
  // значением по умолчанию всегда является NULL, причем я не различаю: это NULL помещенный в хранилище 
  // или пустота в хранилище, интерпретированная как NULL
  //
  // Если я хочу использовать другое значение по умолчанию, можно написать:
  //   prefItem.value ?? defaultValue
  // или какой-нибудь объект вроде DefaultValueNotifier(prefItem).value

  PrefItem(
    this.storage,
    this.key,
    {
      @deprecated this.checkValue,
      T initFunc()
    })
  {
    this._initCompleter = Completer<PrefItem<T>>();
    this._initCompleteFuture = this._initCompleter.future;

    if (initFunc!=null)
      this._init(initFunc);
    else
      this.read();
  }

  T _value;
  bool _valueInitialized = false;

  final String key;
  final PrefsStorage storage;

  final CheckValueFunc<T> checkValue;

  ////////
  // firstReadOrWrite позволяет дождаться загрузки интересующего значения

  Completer<PrefItem<T>> _initCompleter;
  Future<PrefItem<T>> _initCompleteFuture;
  Future<PrefItem<T>> get initialized => _initCompleteFuture;
  bool get isInitialized => _initCompleter.isCompleted;

  /////////
  
  //final Future init

  Future<T> read() async
  {
    // читает значение из хранилища, изменяет свойство value 
    
    await this._writeCalls.completed();

    T t;

    if (T==int)
      t =  await storage.getInt(key) as T;
    else if (T==String)
      t = (await storage.getString(key)) as T;
    else if (T==double)
      t =  await storage.getDouble(key) as T;
    else if (T==bool)
      t =  await storage.getBool(key) as T;
    else if (T==List)
      t =  await storage.getStringList(key) as T;
    else if (T==DateTime)
      t =  await storage.getDateTime(key) as T;
    else
      throw FallThroughError();


    prefnotifiersLog?.call("PrefItem: read $key, result=$t");

    this.value = t;
    return t;
  }

  Future<T> _init(T initFunc()) async
  {
    //if (this.isInitialized)
      //throw StateError("");

    T t = await this.read();
    if (t!=null)
      return t;

    t = initFunc();
    if (t==null)
      throw ArgumentError("Init returns NULL.");
    await this.write(t);

    return this.read();
  }

  Future<bool> defined() async
  {
    return (await this.read())!=null;
  }

  Future<T> adjust(AdjustFunc f) async
  {
    var oldVal = await this.read();
    var newVal = f(oldVal);
    await this.write(newVal);
    return newVal;
  }

  Future<void> write(T value)
  {
    // значение value обновляем синхронно, а пишем после этого асинхронно.
    // Т.е. сразу после вызова у нас появится обновленное value, но сохранится оно с задержкой.

    if (this.checkValue!=null)
      this.checkValue(value);
    this.value = value;

    return this._writeAsync(value);
  }

  // этот объект позволит дождаться окончания всех процедур записи, прежде чем значение будет прочитано
  final _writeCalls = AwaitableCalls();

  Future<void> _writeAsync(T value) async
  {
    prefnotifiersLog?.call("Writing $key=$value");

    this._writeCalls.run(() async {

      if (T == int)
        await storage.setInt(key, value as int);
      else if (T == String)
        await storage.setString(key, value as String);
      else if (T == double)
        await storage.setDouble(key, value as double);
      else if (T == bool)
        await storage.setBool(key, value as bool);
      else if (T == DateTime)
        await storage.setDateTime(key, value as DateTime);
      else if (T == List)
        await storage.setStringList(key, value as List<String>);
      else
        throw FallThroughError();
    });
  }

  set value(T newValue)
  {
    if (this._valueInitialized && newValue==this._value)
      return;

    if (this.checkValue!=null)
      this.checkValue(newValue);

    this._value = newValue;
    this._valueInitialized = true;

    this.notifyListeners();
    
    if (!this._initCompleter.isCompleted)
      this._initCompleter.complete(this);

    this._writeAsync(newValue);
  }

  T get value
  {
    if (!this._valueInitialized)
      return null;
    return this._value;
  }

  Future<T> get initializedValue => this.initialized.then((prefitem) => prefitem.value);

  void toWaitList(List<Future> list)
  {
    list.add(this.initialized);
  }
}