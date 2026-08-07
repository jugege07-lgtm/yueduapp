import 'package:hive_flutter/hive_flutter.dart';
import '../models/book.dart';

/// 书籍本地存储（Hive 单盒），封装增删改查与排序持久化。
class BookStore {
  static const String _boxName = 'books';
  static late Box<Book> _box;

  static Future<void> init() async {
    await Hive.initFlutter();
    Hive.registerAdapter(BookAdapter());
    _box = await Hive.openBox<Book>(_boxName);
  }

  static Box<Book> get box => _box;

  /// 按 sortWeight 升序返回全部书籍
  static List<Book> allSorted() {
    final list = _box.values.toList();
    list.sort((a, b) => a.sortWeight.compareTo(b.sortWeight));
    return list;
  }

  /// 新增书籍：权重排到末尾
  static Future<Book> addBook(Book book) async {
    final maxWeight =
        _box.values.fold<int>(0, (m, b) => b.sortWeight > m ? b.sortWeight : m);
    book.sortWeight = maxWeight + 1;
    await _box.add(book);
    return book;
  }

  /// 拖拽排序后持久化：按列表顺序重写 sortWeight
  static Future<void> persistOrder(List<Book> ordered) async {
    for (var i = 0; i < ordered.length; i++) {
      ordered[i].sortWeight = i;
      await ordered[i].save();
    }
  }

  static Future<void> deleteBook(Book book) async {
    await book.delete();
  }

  static Future<void> saveBook(Book book) async {
    await book.save();
  }
}
