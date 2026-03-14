import 'dart:collection';

class Entity {
  const Entity();
}

class Id {
  final bool assignable;

  const Id({this.assignable = false});
}

class Index {
  const Index();
}

class Unique {
  const Unique();
}

class Backlink {
  final String? to;

  const Backlink([this.to]);
}

class Property {
  final PropertyType? type;

  const Property({this.type});
}

enum PropertyType { dateNano, date, byteVector }

class Transient {
  const Transient();
}

class ToMany<T> extends ListBase<T> {
  final List<T> _inner = <T>[];

  @override
  int get length => _inner.length;

  @override
  set length(int newLength) {
    _inner.length = newLength;
  }

  @override
  T operator [](int index) => _inner[index];

  @override
  void operator []=(int index, T value) {
    _inner[index] = value;
  }

  @override
  void add(T element) => _inner.add(element);

  @override
  void addAll(Iterable<T> iterable) => _inner.addAll(iterable);

  @override
  void insert(int index, T element) => _inner.insert(index, element);

  @override
  T removeAt(int index) => _inner.removeAt(index);

  @override
  bool remove(Object? element) => _inner.remove(element);

  @override
  void clear() => _inner.clear();
}

class ToOne<T> {
  T? target;
  int targetId = 0;
}
