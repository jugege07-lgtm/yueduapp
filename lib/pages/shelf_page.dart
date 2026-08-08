import 'package:flutter/material.dart';
import '../models/book.dart';
import '../data/book_store.dart';
import '../services/txt_importer.dart';
import '../app_config.dart';
import '../widgets/book_card.dart';
import 'reader_page.dart';

/// 书架主页。
///
/// 交互（三个手势互不冲突）：
/// - 点击卡片 → 打开阅读
/// - 长按卡片 → 弹底部菜单（移到顶部/上移/下移/移到底部/删除）
///
/// 设计取舍：曾尝试 `flutter_reorderable_grid_view` 实现长按拖拽排序，
/// 但该包在小米 15 + Material 3 下 children 非空时整个 body 渲染为整块灰色
/// （与 surfaceTintColor、enableLongPress 设置均无关，包内部 Stack/Overlay 的
/// 渲染兼容性问题）。为保证稳定，改用稳定 GridView.builder + 长按菜单排序：
/// 多次点"上移/下移"按钮即可任意重排，与拖拽的最终结果完全等价。
class ShelfPage extends StatefulWidget {
  const ShelfPage({super.key});

  @override
  State<ShelfPage> createState() => _ShelfPageState();
}

class _ShelfPageState extends State<ShelfPage> {
  List<Book> _books = [];
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() {
    setState(() => _books = BookStore.allSorted());
  }

  Future<void> _import() async {
    final imported = await TxtImporter.pickAndImport();
    if (imported.isEmpty) return;
    for (final b in imported) {
      await BookStore.addBook(b);
    }
    _refresh();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已导入 ${imported.length} 本')),
      );
    }
  }

  void _confirmDelete(Book b) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除本书'),
        content: Text('确定删除《${b.title}》吗？该操作不可撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              await BookStore.deleteBook(b);
              if (mounted) Navigator.pop(ctx);
              _refresh();
            },
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }

  void _open(Book b) {
    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (_) => ReaderPage(book: b, handler: audioHandler),
          ),
        )
        .then((_) => _refresh());
  }

  void _moveTo(Book b, int newIndex) {
    final oldIndex = _books.indexOf(b);
    if (oldIndex < 0) return;
    setState(() {
      _books.removeAt(oldIndex);
      final clamped = newIndex.clamp(0, _books.length);
      _books.insert(clamped, b);
    });
    BookStore.persistOrder(_books);
  }

  void _moveRelative(Book b, int delta) {
    final i = _books.indexOf(b);
    if (i < 0) return;
    _moveTo(b, i + delta);
  }

  /// 长按弹底部菜单（含：移到顶部/上移/下移/移到底部/删除）
  void _showReorderSheet(Book b) {
    final i = _books.indexOf(b);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                b.title,
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w600),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.vertical_align_top),
              title: const Text('移到顶部'),
              enabled: i > 0,
              onTap: () {
                Navigator.pop(ctx);
                _moveTo(b, 0);
              },
            ),
            ListTile(
              leading: const Icon(Icons.arrow_upward),
              title: const Text('上移'),
              enabled: i > 0,
              onTap: () {
                Navigator.pop(ctx);
                _moveRelative(b, -1);
              },
            ),
            ListTile(
              leading: const Icon(Icons.arrow_downward),
              title: const Text('下移'),
              enabled: i < _books.length - 1,
              onTap: () {
                Navigator.pop(ctx);
                _moveRelative(b, 1);
              },
            ),
            ListTile(
              leading: const Icon(Icons.vertical_align_bottom),
              title: const Text('移到底部'),
              enabled: i < _books.length - 1,
              onTap: () {
                Navigator.pop(ctx);
                _moveTo(b, _books.length);
              },
            ),
            const Divider(height: 1),
            ListTile(
              leading:
                  const Icon(Icons.delete_outline, color: Color(0xFFE53935)),
              title: const Text('删除',
                  style: TextStyle(color: Color(0xFFE53935))),
              onTap: () {
                Navigator.pop(ctx);
                _confirmDelete(b);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('我的小说'),
        actions: [
          IconButton(
            onPressed: _import,
            icon: const Icon(Icons.add),
            tooltip: '导入 TXT',
          ),
        ],
      ),
      body: _books.isEmpty
          ? _emptyHint()
          : GridView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(8),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 0.72,
              ),
              itemCount: _books.length,
              itemBuilder: (ctx, i) {
                final b = _books[i];
                return GestureDetector(
                  onLongPress: () => _showReorderSheet(b),
                  child: BookCard(
                    key: ValueKey(b.key),
                    book: b,
                    onTap: () => _open(b),
                    onDelete: () => _confirmDelete(b),
                  ),
                );
              },
            ),
    );
  }

  Widget _emptyHint() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.menu_book_outlined,
              size: 64, color: const Color(0xFF888888)),
          const SizedBox(height: 16),
          const Text(
            '书架空空如也',
            style: TextStyle(fontSize: 16, color: Color(0xFF888888)),
          ),
          const SizedBox(height: 8),
          const Text(
            '点击右上角 + 导入 TXT',
            style: TextStyle(fontSize: 13, color: Color(0xFF888888)),
          ),
        ],
      ),
    );
  }
}