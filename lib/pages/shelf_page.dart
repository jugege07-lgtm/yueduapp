import 'package:flutter/material.dart';
import 'package:flutter_reorderable_grid_view/widgets/widgets.dart';
import 'package:flutter_reorderable_grid_view/entities/order_update_entity.dart';
import '../models/book.dart';
import '../data/book_store.dart';
import '../services/txt_importer.dart';
import '../app_config.dart';
import '../widgets/book_card.dart';
import 'reader_page.dart';

/// 书架主页：标题“我的小说” + 右上角“+导入TXT”，书籍卡片网格。
/// 长按 1 秒拖拽排序（松手保存权重）；卡片 × 删除（弹确认框）。
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
              enableLongPress: true,
              longPressDelay: const Duration(milliseconds: 1000),
              children: _books
                  .map(
                    (b) => BookCard(
                      key: ValueKey(b.key),
                      book: b,
                      onTap: () => _open(b),
                      onDelete: () => _confirmDelete(b),
                    ),
                  )
                  .toList(),
              onReorder: (updates) {
                for (final OrderUpdateEntity u in updates) {
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
