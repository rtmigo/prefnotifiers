# prefnotifiers

This library makes it easy to use [shared_preferences](https://pub.dev/packages/shared_preferences) with
state management libraries like [provider](https://pub.dev/packages/provider) or `ValueListenableBuilder` widgets.

## Why turn preferences into objects?

Suppose, we have parameter, that can be read with [shared_preferences](https://pub.dev/packages/shared_preferences) like that:

```dart
final prefs = await SharedPreferences.getInstance();
int paramValue = await prefs.getInt("TheParameter");
```

There are two lines of problem:

- This code is asynchronous. We cannot use such code directly when building a widget.

- The same data is now represented by two entities: the `paramValue` variable and
the real storage. Which is conceptually not wise.

This library suggests using `PrefItem` object for the same task:

```dart
final param = PrefItem<int>(SharedPrefsStorage(), "TheParameter");
```

- `param` object can be used as the only representation of `"TheParameter"` in the whole program
- `param.value` allows indirectly read and write the shared preferences value
- synchronous `build` methods can access value immediately
- `param.addListener` makes it possible to track changes of the value


## PrefItem

PrefItem serves as a **model** for an individual parameter stored in shared preferences. Although I/O operations on
shared preferences are asynchronous, the `PrefItem.value` is always available for synchronous calls.
It provides *"the best value we have for the moment"*. The actual read/write operations happen in background.


Let's declare the model for this parameter:

```dart
final param = PrefItem<int>(SharedPrefsStorage(), "TheParameter");
```

Reading is is not finished yet. But we already can access `param.value`. By default, it returns `null`.
We can use it in synchronous code:

```dart
Widget build(BuildContext context) {
    if (param.value==null)
        return Text("Not initialized yet");
    else
        return Text("Value is ${param.value}");
}
```

Since `PrefItem` inherits from the `ValueNotifier` class, we can automatically rebuild the widget when the `param` will be available:

```dart
Widget build(BuildContext context) {
    return ValueListenableBuilder(
        valueListenable: param,
        builder: (BuildContext context, int value, Widget child) {
            if (value==null)
                return Text("Not initialized yet");
            else
                return Text("Value is $value");
        });
}
```

The code above will also rebuild the widget when value is changed. Let's change the value in a button callback:

```dart
onTap: () {
    // param.value is 3, shared prefs is 3

    param.value += 1;
    param.value += 1;

    // param.value changed to 5.
    // The widget will rebuild momentarily (i.e. on the next frame)
    //
    // Shared preferences still contain value 3. But asynchronous writing
    // already started. It will rewrite value in a few milliseconds
}
```

## PrefsStorage

Each `PrefItem` relies on a `PrefsStorage` that actually stores the values.  Where and how the data is stored depends
on which object is passed to the `PrefItem` constructor.

```dart

final keptInSharedPreferences = PrefItem<int>(SharedPrefsStorage(), ...);

final keptInRam = PrefItem<String>(RamPrefsStorage(), ...);

final keptInFile = PrefItem<String>(CustomJsonPrefsStorage(), ...);

```

But usually the same instance of `PrefsStorage` shared between multiple `PrefItem` objects:

```dart

final storage = inTestingMode ? RamPrefsStorage() : SharedPrefsStorage();

final a =  PrefItem<String>(storage, "nameA");
final b =  PrefItem<double>(storage, "nameB");

```

- `PrefsStorage` is an abstract base class describing a storage. A descendant should be able of reading and writing
named values of types `int`, `double`, `String`, `StringList` and `DateTime`.

- `SharedPrefsStorage` stores preferences in platform-dependent [shared_preferences](https://pub.dev/packages/shared_preferences).

- `RamPrefsStorage` stores preferences in RAM. This class is mostly useful for testing.





