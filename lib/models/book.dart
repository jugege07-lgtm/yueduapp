import 'package:hive/hive.dart';

/// 一本书的本地数据模型。
/// 全部字段非 null（导入时必填），存储于 Hive，包含：
/// - 书架排序权重 [sortWeight]
/// - 阅读进度 [currentPage]/[progressPercent]/[currentParagraph]
/// - 上次阅读时间 [lastReadAt]
/// - 每本书独立的听书倍速 [ttsSpeed]
class Book extends HiveObject {
  String title;
  String path; // 原始 TXT 文件路径（不复制全文，读时再解码）
  String encoding; // 检测到的编码，如 UTF-8 / GBK
  int sortWeight;
  int lastReadAt; // 1970 起的毫秒数，0 表示未读
  double progressPercent;
  int currentPage;
  int currentParagraph;
  double ttsSpeed;

  Book({
    required this.title,
    required this.path,
    required this.encoding,
    this.sortWeight = 0,
    this.lastReadAt = 0,
    this.progressPercent = 0.0,
    this.currentPage = 0,
    this.currentParagraph = 0,
    this.ttsSpeed = 1.0,
  });
}

/// 手写 Hive 适配器，避免生成代码步骤（build_runner）。
/// 字段写入顺序与读取顺序必须一致。
class BookAdapter extends TypeAdapter<Book> {
  @override
  final int typeId = 0;

  @override
  Book read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Book(
      title: fields[0] as String,
      path: fields[1] as String,
      encoding: fields[2] as String,
      sortWeight: fields[3] as int,
      lastReadAt: fields[4] as int,
      progressPercent: fields[5] as double,
      currentPage: fields[6] as int,
      currentParagraph: fields[7] as int,
      ttsSpeed: fields[8] as double,
    );
  }

  @override
  void write(BinaryWriter writer, Book obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.title)
      ..writeByte(1)
      ..write(obj.path)
      ..writeByte(2)
      ..write(obj.encoding)
      ..writeByte(3)
      ..write(obj.sortWeight)
      ..writeByte(4)
      ..write(obj.lastReadAt)
      ..writeByte(5)
      ..write(obj.progressPercent)
      ..writeByte(6)
      ..write(obj.currentPage)
      ..writeByte(7)
      ..write(obj.currentParagraph)
      ..writeByte(8)
      ..write(obj.ttsSpeed);
  }
}
