import 'package:flutter/material.dart';
import 'package:flutter_reorderable_grid_view/widgets/widgets.dart';
import 'package:flutter_reorderable_grid_view/entities/reorder_update_entity.dart';
import '../models/book.dart';
import '../data/book_store.dart';
import '../services/txt_importer.dart';
import '../app_config.dart';
import '../widgets/book_card.dart';
import 'reader_page.dart';

/// 书架主页。
///
/// 交互：
/// - 点击卡片 → 打开阅读
/// - 短按+拖动卡片 → 自由拖动排序（松手保存）
/// - 长按卡片 → 弹底部菜单（移到顶部/上移/下移/移到底部/删除）
///
/// 手势分工（避免冲突）：
/// - InkWell（BookCard 内）：onTap → 打开阅读
/// - Draggable（ReorderableBuilder 内）：onPan → 拖动排序
/// - GestureDetector（本文件加）：onLongPress → 弹菜单
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

  /// 长按弹底部菜单
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
              leading: const Icon(Icons.delete_outline,
                  color: Color(0xFFE53935)),
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
          : ReorderableBuilder(
              scrollController: _scrollController,
              // false = 短按+拖动立即触发排序；true = 长按才拖（与弹窗冲突）
              enableLongPress: false,
              children: _books
                  .map(
                    (b) => GestureDetector(
                      // 只监听长按弹窗；短按交给 BookCard 内的 InkWell；拖动交给 Draggable
                      onLongPress: () => _showReorderSheet(b),
                      child: BookCard(
                        key: ValueKey(b.key),
                        book: b,
                        onTap: () => _open(b),
                        onDelete: () => _confirmDelete(b),
                      ),
                    ),
                  )
                  .toList(),
              onReorderPositions: (updates) {
                for (final ReorderUpdateEntity u in updates) {
                  if (u.oldIndex == u.newIndex) continue;
                  final b = _books.removeAt(u.oldIndex);
                  _books.insert(u.newIndex, b);
                }
                BookStore.persistOrder(_books);
                setState(() {});
              },
              builder: (children) => GridView.count(
                crossAxisCount: 2,
                controller: _scrollController,
                padding: const EdgeInsets.all(8),
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 0.72,
                children: children,
              ),
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