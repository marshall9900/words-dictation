import 'package:get/get.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/models.dart';
import '../utils/sm2_scheduler.dart';

/// 本地数据库服务（sqflite + 艾宾浩斯复习算法）
class LocalDbService extends GetxService {
  static const int _dbVersion = 2;
  static const String _dbName = 'words_dictation.db';

  Database? _db;

  // ── Schema helpers ──────────────────────────────────────────────────────────

  static const String _createWordsTable = '''
    CREATE TABLE IF NOT EXISTS words (
      id TEXT PRIMARY KEY,
      word TEXT NOT NULL,
      translation TEXT NOT NULL,
      phonetic TEXT,
      audio_url TEXT,
      book_id TEXT,
      difficulty INTEGER
    )
  ''';

  static const String _createWrongWordsTable = '''
    CREATE TABLE IF NOT EXISTS wrong_words (
      word_id TEXT PRIMARY KEY,
      word TEXT NOT NULL,
      meaning TEXT NOT NULL DEFAULT '',
      phonetic TEXT,
      audio_url TEXT,
      book_id TEXT,
      difficulty INTEGER,
      wrong_count INTEGER NOT NULL DEFAULT 1,
      last_wrong_at INTEGER,
      next_review_at INTEGER,
      sm2_repetitions INTEGER NOT NULL DEFAULT 0,
      sm2_ease_factor REAL NOT NULL DEFAULT 2.5,
      sm2_interval_days INTEGER NOT NULL DEFAULT 1,
      mastered INTEGER NOT NULL DEFAULT 0
    )
  ''';

  static const String _createDictationTasksTable = '''
    CREATE TABLE IF NOT EXISTS dictation_tasks (
      id TEXT PRIMARY KEY,
      book_id TEXT NOT NULL,
      created_at INTEGER NOT NULL,
      completed_at INTEGER,
      total_words INTEGER NOT NULL DEFAULT 0,
      correct_count INTEGER NOT NULL DEFAULT 0
    )
  ''';

  // ── Lifecycle ───────────────────────────────────────────────────────────────

  /// 初始化数据库
  Future<void> initialize() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, _dbName);

    _db = await openDatabase(
      path,
      version: _dbVersion,
      onCreate: (db, version) async {
        await db.execute(_createWordsTable);
        await db.execute(_createWrongWordsTable);
        await db.execute(_createDictationTasksTable);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          // v1 → v2: add SM-2 fields to wrong_words
          await _alterTableSafe(db, 'wrong_words', 'sm2_repetitions', 'INTEGER NOT NULL DEFAULT 0');
          await _alterTableSafe(db, 'wrong_words', 'sm2_ease_factor', 'REAL NOT NULL DEFAULT 2.5');
          await _alterTableSafe(db, 'wrong_words', 'sm2_interval_days', 'INTEGER NOT NULL DEFAULT 1');
          await _alterTableSafe(db, 'wrong_words', 'next_review_at', 'INTEGER');
        }
      },
    );
  }

  /// 安全 ALTER TABLE：列已存在时不报错（Web/sqflite_common 兜底）
  Future<void> _alterTableSafe(Database db, String table, String column, String typeDef) async {
    try {
      await db.execute('ALTER TABLE $table ADD COLUMN $column $typeDef');
    } catch (_) {
      // Column likely already exists — ignore
    }
  }

  Database get _database {
    assert(_db != null, 'LocalDbService not initialized. Call initialize() first.');
    return _db!;
  }

  // ── Words cache ─────────────────────────────────────────────────────────────

  Future<void> cacheWords(List<WordItem> words) async {
    final db = _database;
    final batch = db.batch();
    for (final w in words) {
      batch.insert(
        'words',
        _wordItemToRow(w),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<List<WordItem>> getCachedWords({String? bookId}) async {
    final db = _database;
    final rows = bookId != null
        ? await db.query('words', where: 'book_id = ?', whereArgs: [bookId])
        : await db.query('words');
    return rows.map(_rowToWordItem).toList();
  }

  // ── Wrong words (艾宾浩斯) ──────────────────────────────────────────────────

  Future<void> saveWrongWord(WrongWord word) async {
    final db = _database;
    await db.insert(
      'wrong_words',
      _wrongWordToRow(word),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// 查询单条错词记录（按 word_id）
  Future<WrongWord?> getWrongWord(String wordId) async {
    final db = _database;
    final rows = await db.query('wrong_words', where: 'word_id = ?', whereArgs: [wordId], limit: 1);
    if (rows.isEmpty) return null;
    return _rowToWrongWord(rows.first);
  }

  Future<List<WrongWord>> getWrongWords() async {
    final db = _database;
    final rows = await db.query('wrong_words');
    return rows.map(_rowToWrongWord).toList();
  }

  /// 查询今日待复习的错词（艾宾浩斯调度）
  Future<List<WrongWord>> getTodayReviewWords() async {
    final db = _database;
    final now = DateTime.now();
    final endOfToday = DateTime(now.year, now.month, now.day, 23, 59, 59);
    final endMs = endOfToday.millisecondsSinceEpoch;

    // next_review_at IS NULL（新词）or <= 今日结束时间
    final rows = await db.query(
      'wrong_words',
      where: 'next_review_at IS NULL OR next_review_at <= ?',
      whereArgs: [endMs],
    );
    return rows.map(_rowToWrongWord).toList();
  }

  /// 复习完成后更新艾宾浩斯状态
  Future<void> updateAfterReview({
    required String wordId,
    required int quality, // 0-5
  }) async {
    final db = _database;
    final rows = await db.query('wrong_words', where: 'word_id = ?', whereArgs: [wordId]);
    if (rows.isEmpty) return;

    final current = _rowToWrongWord(rows.first);
    final scheduler = SM2Scheduler();
    final updated = scheduler.updateSchedule(current, quality: quality);

    await db.update(
      'wrong_words',
      {
        'sm2_repetitions': updated.sm2RepetitionCount,
        'sm2_ease_factor': updated.sm2Easiness,
        'sm2_interval_days': updated.sm2IntervalDays,
        'next_review_at': updated.nextReviewAt?.millisecondsSinceEpoch,
      },
      where: 'word_id = ?',
      whereArgs: [wordId],
    );
  }

  /// 更新旧式复习进度（保持向后兼容）
  Future<void> updateReviewProgress(String wordId, {required bool correct}) async {
    await updateAfterReview(wordId: wordId, quality: correct ? 4 : 1);
  }

  // ── Dictation records ───────────────────────────────────────────────────────

  Future<void> saveDictationRecord(DictationTask task) async {
    final db = _database;
    await db.insert(
      'dictation_tasks',
      {
        'id': task.id,
        'book_id': task.bookId,
        'created_at': task.createdAt.millisecondsSinceEpoch,
        'completed_at': task.completedAt?.millisecondsSinceEpoch,
        'total_words': task.totalWords,
        'correct_count': task.correctCount,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<DictationTask>> getDictationHistory({int limit = 20}) async {
    final db = _database;
    final rows = await db.query(
      'dictation_tasks',
      orderBy: 'created_at DESC',
      limit: limit,
    );
    return rows.map(_rowToDictationTask).toList();
  }

  // ── Row ↔ Model converters ──────────────────────────────────────────────────

  Map<String, dynamic> _wordItemToRow(WordItem w) => {
        'id': w.id,
        'word': w.word,
        'translation': w.translation,
        'phonetic': w.phonetic,
        'audio_url': w.audioUrl,
        'book_id': w.bookId,
        'difficulty': w.difficulty,
      };

  WordItem _rowToWordItem(Map<String, dynamic> row) => WordItem(
        id: row['id'] as String,
        word: row['word'] as String,
        translation: row['translation'] as String,
        phonetic: row['phonetic'] as String?,
        audioUrl: row['audio_url'] as String?,
        bookId: row['book_id'] as String?,
        difficulty: row['difficulty'] as int?,
      );

  Map<String, dynamic> _wrongWordToRow(WrongWord w) => {
        'word_id': w.wordId,
        'word': w.word.word,
        'meaning': w.word.meaning,
        'phonetic': w.word.phonetic,
        'audio_url': w.word.audioUrl,
        'book_id': w.word.bookId,
        'difficulty': w.word.difficulty,
        'wrong_count': w.wrongCount,
        'last_wrong_at': w.lastWrongAt?.millisecondsSinceEpoch,
        'next_review_at': w.nextReviewAt?.millisecondsSinceEpoch,
        'sm2_repetitions': w.sm2RepetitionCount,
        'sm2_ease_factor': w.sm2Easiness,
        'sm2_interval_days': w.sm2IntervalDays,
        'mastered': w.mastered ? 1 : 0,
      };

  WrongWord _rowToWrongWord(Map<String, dynamic> row) {
    final wi = WordItem(
      id: row['word_id'] as String,
      word: row['word'] as String,
      meaning: row['meaning'] as String? ?? '',
      phonetic: row['phonetic'] as String?,
      audioUrl: row['audio_url'] as String?,
      bookId: row['book_id'] as String?,
      difficulty: row['difficulty'] as int?,
    );
    return WrongWord(
      wordId: row['word_id'] as String,
      word: wi,
      wrongCount: (row['wrong_count'] as int?) ?? 0,
      lastWrongAt: row['last_wrong_at'] != null
          ? DateTime.fromMillisecondsSinceEpoch(row['last_wrong_at'] as int)
          : null,
      nextReviewAt: row['next_review_at'] != null
          ? DateTime.fromMillisecondsSinceEpoch(row['next_review_at'] as int)
          : null,
      sm2RepetitionCount: (row['sm2_repetitions'] as int?) ?? 0,
      sm2Easiness: (row['sm2_ease_factor'] as num?)?.toDouble() ?? 2.5,
      sm2IntervalDays: (row['sm2_interval_days'] as int?) ?? 1,
      mastered: (row['mastered'] as int?) == 1,
    );
  }

  DictationTask _rowToDictationTask(Map<String, dynamic> row) => DictationTask(
        taskId: row['id'] as String,
        bookId: row['book_id'] as String?,
        words: const [],
        createdAt: DateTime.fromMillisecondsSinceEpoch(row['created_at'] as int),
        completedAt: row['completed_at'] != null
            ? DateTime.fromMillisecondsSinceEpoch(row['completed_at'] as int)
            : null,
        totalWords: (row['total_words'] as int?) ?? 0,
        correctCount: (row['correct_count'] as int?) ?? 0,
      );
}
