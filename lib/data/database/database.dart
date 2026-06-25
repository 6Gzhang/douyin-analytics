import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../../security/security_service.dart';

/// 应用数据库
class AppDatabase {
  static Database? _db;

  static Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDb();
    return _db!;
  }

  static Future<Database> _initDb() async {
    final dir = await getApplicationDocumentsDirectory();
    final path = p.join(dir.path, 'dyanalytics.db');
    return await openDatabase(
      path,
      version: 6,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE videos (
            id TEXT PRIMARY KEY,
            title TEXT NOT NULL,
            cover_url TEXT,
            create_time INTEGER NOT NULL,
            duration REAL,
            video_url TEXT,
            is_top INTEGER DEFAULT 0,
            source TEXT DEFAULT '',
            source_id TEXT DEFAULT ''
          )
        ''');
        await db.execute('''
          CREATE TABLE video_metrics (
            video_id TEXT PRIMARY KEY,
            play_count INTEGER DEFAULT 0,
            like_count INTEGER DEFAULT 0,
            comment_count INTEGER DEFAULT 0,
            share_count INTEGER DEFAULT 0,
            collect_count INTEGER DEFAULT 0,
            finish_rate REAL,
            avg_watch_duration REAL,
            two_second_exit_rate REAL DEFAULT 0,
            cover_ctr REAL DEFAULT 0,
            profile_visits INTEGER DEFAULT 0,
            full_play_count INTEGER DEFAULT 0,
            five_second_finish_rate REAL DEFAULT 0,
            new_followers INTEGER DEFAULT 0,
            total_duration REAL,
            traffic_recommend REAL,
            traffic_search REAL,
            traffic_follow REAL,
            traffic_city REAL,
            traffic_profile REAL,
            traffic_hotspot REAL,
            traffic_doujia REAL,
            audience_male_ratio REAL,
            audience_age_dist TEXT,
            audience_region_dist TEXT,
            audience_tgi TEXT,
            like_rate REAL,
            comment_rate REAL,
            share_rate REAL,
            collect_rate REAL,
            interaction_rate REAL,
            fetched_at INTEGER NOT NULL,
            source TEXT NOT NULL,
            updated_at INTEGER DEFAULT 0,
            FOREIGN KEY (video_id) REFERENCES videos(id)
          )
        ''');
        await db.execute('''
          CREATE TABLE csv_imports (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            file_name TEXT NOT NULL,
            file_path TEXT DEFAULT '',
            row_count INTEGER DEFAULT 0,
            imported_count INTEGER DEFAULT 0,
            skipped_count INTEGER DEFAULT 0,
            imported_at INTEGER NOT NULL,
            file_hash TEXT DEFAULT ''
          )
        ''');
        await db.execute('''
          CREATE TABLE feishu_config (
            key TEXT PRIMARY KEY,
            value TEXT NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE douyin_auth (
            key TEXT PRIMARY KEY,
            value TEXT NOT NULL,
            updated_at INTEGER NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE audit_logs (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            timestamp INTEGER NOT NULL,
            level TEXT NOT NULL,
            event_type TEXT,
            message TEXT NOT NULL,
            metadata TEXT
          )
        ''');
        await db.execute('''
          CREATE TABLE security_config (
            key TEXT PRIMARY KEY,
            value TEXT NOT NULL,
            updated_at INTEGER NOT NULL
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('''CREATE TABLE IF NOT EXISTS feishu_config (key TEXT PRIMARY KEY, value TEXT NOT NULL)''');
          await db.execute('''CREATE TABLE IF NOT EXISTS douyin_auth (key TEXT PRIMARY KEY, value TEXT NOT NULL, updated_at INTEGER NOT NULL)''');
        }
        if (oldVersion < 3) {
          final cols = await db.rawQuery("PRAGMA table_info('videos')");
          final colNames = cols.map((c) => c['name']).toSet();
          if (!colNames.contains('is_top')) await db.execute("ALTER TABLE videos ADD COLUMN is_top INTEGER DEFAULT 0");
          if (!colNames.contains('source')) await db.execute("ALTER TABLE videos ADD COLUMN source TEXT DEFAULT ''");
          if (!colNames.contains('source_id')) await db.execute("ALTER TABLE videos ADD COLUMN source_id TEXT DEFAULT ''");
          final mcols = await db.rawQuery("PRAGMA table_info('video_metrics')");
          final mcolNames = mcols.map((c) => c['name']).toSet();
          if (!mcolNames.contains('updated_at')) await db.execute("ALTER TABLE video_metrics ADD COLUMN updated_at INTEGER DEFAULT 0");
          final icols = await db.rawQuery("PRAGMA table_info('csv_imports')");
          final icolNames = icols.map((c) => c['name']).toSet();
          if (!icolNames.contains('file_path')) await db.execute("ALTER TABLE csv_imports ADD COLUMN file_path TEXT DEFAULT ''");
          if (!icolNames.contains('row_count')) await db.execute("ALTER TABLE csv_imports ADD COLUMN row_count INTEGER DEFAULT 0");
          if (!icolNames.contains('imported_count')) await db.execute("ALTER TABLE csv_imports ADD COLUMN imported_count INTEGER DEFAULT 0");
          if (!icolNames.contains('skipped_count')) await db.execute("ALTER TABLE csv_imports ADD COLUMN skipped_count INTEGER DEFAULT 0");
        }
        if (oldVersion < 4) {
          final mcols = await db.rawQuery("PRAGMA table_info('video_metrics')");
          final mcolNames = mcols.map((c) => c['name']).toSet();
          if (!mcolNames.contains('two_second_exit_rate')) await db.execute("ALTER TABLE video_metrics ADD COLUMN two_second_exit_rate REAL DEFAULT 0");
          if (!mcolNames.contains('cover_ctr')) await db.execute("ALTER TABLE video_metrics ADD COLUMN cover_ctr REAL DEFAULT 0");
          if (!mcolNames.contains('profile_visits')) await db.execute("ALTER TABLE video_metrics ADD COLUMN profile_visits INTEGER DEFAULT 0");
          if (!mcolNames.contains('full_play_count')) await db.execute("ALTER TABLE video_metrics ADD COLUMN full_play_count INTEGER DEFAULT 0");
          if (!mcolNames.contains('five_second_finish_rate')) await db.execute("ALTER TABLE video_metrics ADD COLUMN five_second_finish_rate REAL DEFAULT 0");
        }
        if (oldVersion < 5) {
          final mcols = await db.rawQuery("PRAGMA table_info('video_metrics')");
          final mcolNames = mcols.map((c) => c['name']).toSet();
          if (!mcolNames.contains('new_followers')) await db.execute("ALTER TABLE video_metrics ADD COLUMN new_followers INTEGER DEFAULT 0");
          if (!mcolNames.contains('total_duration')) await db.execute("ALTER TABLE video_metrics ADD COLUMN total_duration REAL");
          if (!mcolNames.contains('traffic_profile')) await db.execute("ALTER TABLE video_metrics ADD COLUMN traffic_profile REAL");
          if (!mcolNames.contains('traffic_hotspot')) await db.execute("ALTER TABLE video_metrics ADD COLUMN traffic_hotspot REAL");
          if (!mcolNames.contains('traffic_doujia')) await db.execute("ALTER TABLE video_metrics ADD COLUMN traffic_doujia REAL");
          if (!mcolNames.contains('like_rate')) await db.execute("ALTER TABLE video_metrics ADD COLUMN like_rate REAL");
          if (!mcolNames.contains('comment_rate')) await db.execute("ALTER TABLE video_metrics ADD COLUMN comment_rate REAL");
          if (!mcolNames.contains('share_rate')) await db.execute("ALTER TABLE video_metrics ADD COLUMN share_rate REAL");
          if (!mcolNames.contains('collect_rate')) await db.execute("ALTER TABLE video_metrics ADD COLUMN collect_rate REAL");
          if (!mcolNames.contains('interaction_rate')) await db.execute("ALTER TABLE video_metrics ADD COLUMN interaction_rate REAL");
        }
        if (oldVersion < 6) {
          await db.execute('''CREATE TABLE IF NOT EXISTS audit_logs (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            timestamp INTEGER NOT NULL,
            level TEXT NOT NULL,
            event_type TEXT,
            message TEXT NOT NULL,
            metadata TEXT
          )''');
          await db.execute('''CREATE TABLE IF NOT EXISTS security_config (
            key TEXT PRIMARY KEY,
            value TEXT NOT NULL,
            updated_at INTEGER NOT NULL
          )''');
        }
      },
    );
  }

  // ========== Videos ==========

  Future<void> insertVideo(Map<String, dynamic> data) async {
    final db = await AppDatabase.database;
    await db.insert('videos', {
      'id': data['id'],
      'title': data['title'] ?? '',
      'cover_url': data['cover_url'] ?? '',
      'create_time': data['create_time'] ?? 0,
      'is_top': data['is_top'] ?? 0,
      'source': data['source'] ?? '',
      'source_id': data['source_id'] ?? '',
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> upsertVideo({
    required String id,
    required String title,
    String? coverUrl,
    required int createTime,
    double? duration,
    String? videoUrl,
    int isTop = 0,
    String source = '',
    String sourceId = '',
  }) async {
    final db = await AppDatabase.database;
    await db.insert('videos', {
      'id': id,
      'title': title,
      'cover_url': coverUrl,
      'create_time': createTime,
      'duration': duration,
      'video_url': videoUrl,
      'is_top': isTop,
      'source': source,
      'source_id': sourceId,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Map<String, dynamic>>> getAllVideos({String? orderBy}) async {
    final db = await AppDatabase.database;
    if (orderBy == 'plays') {
      return await db.rawQuery('SELECT v.* FROM videos v LEFT JOIN video_metrics m ON m.video_id = v.id ORDER BY m.play_count DESC');
    } else if (orderBy == 'likes') {
      return await db.rawQuery('SELECT v.* FROM videos v LEFT JOIN video_metrics m ON m.video_id = v.id ORDER BY m.like_count DESC');
    }
    return await db.query('videos', orderBy: 'create_time DESC');
  }

  Future<List<Map<String, dynamic>>> getAllVideosWithMetrics({String? orderBy}) async {
    final db = await AppDatabase.database;
    String orderClause = 'v.create_time DESC';
    if (orderBy == 'plays') orderClause = 'COALESCE(m.play_count, 0) DESC';
    if (orderBy == 'likes') orderClause = 'COALESCE(m.like_count, 0) DESC';
    if (orderBy == 'finish_rate') orderClause = 'COALESCE(m.finish_rate, 0) DESC';
    if (orderBy == 'interaction') orderClause = 'COALESCE(m.like_count, 0) + COALESCE(m.comment_count, 0) + COALESCE(m.share_count, 0) DESC';
    return await db.rawQuery('''
      SELECT v.*, 
        m.play_count, m.like_count, m.comment_count, m.share_count, m.collect_count,
        m.finish_rate, m.avg_watch_duration, m.two_second_exit_rate, m.cover_ctr,
        m.profile_visits, m.full_play_count, m.five_second_finish_rate,
        m.traffic_recommend, m.traffic_search, m.traffic_follow, m.traffic_city,
        m.audience_male_ratio, m.audience_age_dist, m.audience_region_dist, m.audience_tgi,
        m.fetched_at, m.source as metric_source, m.updated_at
      FROM videos v
      LEFT JOIN video_metrics m ON m.video_id = v.id
      ORDER BY $orderClause
    ''');
  }

  Future<Map<String, dynamic>?> getVideoById(String id) async {
    final db = await AppDatabase.database;
    final results = await db.query('videos', where: 'id = ?', whereArgs: [id]);
    return results.isNotEmpty ? results.first : null;
  }

  // ========== VideoMetrics ==========

  Future<void> upsertVideoMetrics(Map<String, dynamic> data) async {
    final db = await AppDatabase.database;
    final videoId = data['video_id'];
    final existing = await db.query('video_metrics', where: 'video_id = ?', whereArgs: [videoId]);
    if (existing.isNotEmpty) {
      await db.update('video_metrics', data, where: 'video_id = ?', whereArgs: [videoId]);
    } else {
      await db.insert('video_metrics', data);
    }
  }

  Future<void> upsertMetrics({
    required String videoId,
    int? playCount,
    int? likeCount,
    int? commentCount,
    int? shareCount,
    int? collectCount,
    double? finishRate,
    double? avgWatchDuration,
    double? twoSecondExitRate,
    double? coverCtr,
    int? profileVisits,
    int? fullPlayCount,
    double? fiveSecondFinishRate,
    int? newFollowers,
    double? totalDuration,
    double? trafficRecommend,
    double? trafficSearch,
    double? trafficFollow,
    double? trafficCity,
    double? trafficProfile,
    double? trafficHotspot,
    double? trafficDoujia,
    double? audienceMaleRatio,
    String? audienceAgeDist,
    String? audienceRegionDist,
    String? audienceTgi,
    double? likeRate,
    double? commentRate,
    double? shareRate,
    double? collectRate,
    double? interactionRate,
    required int fetchedAt,
    required String source,
  }) async {
    final db = await AppDatabase.database;
    final existing = await db.query('video_metrics', where: 'video_id = ?', whereArgs: [videoId]);
    if (existing.isNotEmpty) {
      final u = <String, dynamic>{};
      if (playCount != null) u['play_count'] = playCount;
      if (likeCount != null) u['like_count'] = likeCount;
      if (commentCount != null) u['comment_count'] = commentCount;
      if (shareCount != null) u['share_count'] = shareCount;
      if (collectCount != null) u['collect_count'] = collectCount;
      if (finishRate != null) u['finish_rate'] = finishRate;
      if (avgWatchDuration != null) u['avg_watch_duration'] = avgWatchDuration;
      if (twoSecondExitRate != null) u['two_second_exit_rate'] = twoSecondExitRate;
      if (coverCtr != null) u['cover_ctr'] = coverCtr;
      if (profileVisits != null) u['profile_visits'] = profileVisits;
      if (fullPlayCount != null) u['full_play_count'] = fullPlayCount;
      if (fiveSecondFinishRate != null) u['five_second_finish_rate'] = fiveSecondFinishRate;
      if (newFollowers != null) u['new_followers'] = newFollowers;
      if (totalDuration != null) u['total_duration'] = totalDuration;
      if (trafficRecommend != null) u['traffic_recommend'] = trafficRecommend;
      if (trafficSearch != null) u['traffic_search'] = trafficSearch;
      if (trafficFollow != null) u['traffic_follow'] = trafficFollow;
      if (trafficCity != null) u['traffic_city'] = trafficCity;
      if (trafficProfile != null) u['traffic_profile'] = trafficProfile;
      if (trafficHotspot != null) u['traffic_hotspot'] = trafficHotspot;
      if (trafficDoujia != null) u['traffic_doujia'] = trafficDoujia;
      if (audienceMaleRatio != null) u['audience_male_ratio'] = audienceMaleRatio;
      if (audienceAgeDist != null) u['audience_age_dist'] = audienceAgeDist;
      if (audienceRegionDist != null) u['audience_region_dist'] = audienceRegionDist;
      if (audienceTgi != null) u['audience_tgi'] = audienceTgi;
      if (likeRate != null) u['like_rate'] = likeRate;
      if (commentRate != null) u['comment_rate'] = commentRate;
      if (shareRate != null) u['share_rate'] = shareRate;
      if (collectRate != null) u['collect_rate'] = collectRate;
      if (interactionRate != null) u['interaction_rate'] = interactionRate;
      u['fetched_at'] = fetchedAt;
      u['source'] = source;
      u['updated_at'] = DateTime.now().millisecondsSinceEpoch;
      if (u.isNotEmpty) {
        await db.update('video_metrics', u, where: 'video_id = ?', whereArgs: [videoId]);
      }
    } else {
      await db.insert('video_metrics', {
        'video_id': videoId,
        'play_count': playCount ?? 0,
        'like_count': likeCount ?? 0,
        'comment_count': commentCount ?? 0,
        'share_count': shareCount ?? 0,
        'collect_count': collectCount ?? 0,
        'finish_rate': finishRate,
        'avg_watch_duration': avgWatchDuration,
        'two_second_exit_rate': twoSecondExitRate ?? 0,
        'cover_ctr': coverCtr ?? 0,
        'profile_visits': profileVisits ?? 0,
        'full_play_count': fullPlayCount ?? 0,
        'five_second_finish_rate': fiveSecondFinishRate ?? 0,
        'new_followers': newFollowers ?? 0,
        'total_duration': totalDuration,
        'traffic_recommend': trafficRecommend,
        'traffic_search': trafficSearch,
        'traffic_follow': trafficFollow,
        'traffic_city': trafficCity,
        'traffic_profile': trafficProfile,
        'traffic_hotspot': trafficHotspot,
        'traffic_doujia': trafficDoujia,
        'audience_male_ratio': audienceMaleRatio,
        'audience_age_dist': audienceAgeDist,
        'audience_region_dist': audienceRegionDist,
        'audience_tgi': audienceTgi,
        'like_rate': likeRate,
        'comment_rate': commentRate,
        'share_rate': shareRate,
        'collect_rate': collectRate,
        'interaction_rate': interactionRate,
        'fetched_at': fetchedAt,
        'source': source,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      });
    }
  }

  Future<Map<String, dynamic>?> getMetricsForVideo(String videoId) async {
    final db = await AppDatabase.database;
    final results = await db.query('video_metrics', where: 'video_id = ?', whereArgs: [videoId]);
    return results.isNotEmpty ? results.first : null;
  }

  /// Get channel-level aggregated statistics
  Future<Map<String, dynamic>> getChannelStats() async {
    final db = await AppDatabase.database;
    final totalVideos = Sqflite.firstIntValue(
        await db.rawQuery('SELECT COUNT(*) FROM videos')) ?? 0;
    if (totalVideos == 0) {
      return {
        'total_videos': 0,
        'total_plays': 0,
        'total_likes': 0,
        'total_comments': 0,
        'total_shares': 0,
        'total_collects': 0,
        'avg_plays': 0.0,
        'avg_likes': 0.0,
        'avg_comments': 0.0,
        'avg_shares': 0.0,
        'avg_collects': 0.0,
        'avg_finish_rate': 0.0,
        'avg_watch_duration': 0.0,
        'avg_cover_ctr': 0.0,
        'avg_two_second_exit_rate': 0.0,
        'avg_five_second_finish_rate': 0.0,
        'total_profile_visits': 0,
        'total_full_plays': 0,
        'traffic_recommend': 0.0,
        'traffic_search': 0.0,
        'traffic_follow': 0.0,
        'traffic_city': 0.0,
      };
    }
    final stats = await db.rawQuery('''
      SELECT 
        COALESCE(SUM(m.play_count), 0) as total_plays,
        COALESCE(SUM(m.like_count), 0) as total_likes,
        COALESCE(SUM(m.comment_count), 0) as total_comments,
        COALESCE(SUM(m.share_count), 0) as total_shares,
        COALESCE(SUM(m.collect_count), 0) as total_collects,
        COALESCE(AVG(m.play_count), 0) as avg_plays,
        COALESCE(AVG(m.like_count), 0) as avg_likes,
        COALESCE(AVG(m.comment_count), 0) as avg_comments,
        COALESCE(AVG(m.share_count), 0) as avg_shares,
        COALESCE(AVG(m.collect_count), 0) as avg_collects,
        COALESCE(AVG(m.finish_rate), 0) as avg_finish_rate,
        COALESCE(AVG(m.avg_watch_duration), 0) as avg_watch_duration,
        COALESCE(AVG(m.cover_ctr), 0) as avg_cover_ctr,
        COALESCE(AVG(m.two_second_exit_rate), 0) as avg_two_second_exit_rate,
        COALESCE(AVG(m.five_second_finish_rate), 0) as avg_five_second_finish_rate,
        COALESCE(SUM(m.profile_visits), 0) as total_profile_visits,
        COALESCE(SUM(m.full_play_count), 0) as total_full_plays,
        COALESCE(AVG(m.traffic_recommend), 0) as traffic_recommend,
        COALESCE(AVG(m.traffic_search), 0) as traffic_search,
        COALESCE(AVG(m.traffic_follow), 0) as traffic_follow,
        COALESCE(AVG(m.traffic_city), 0) as traffic_city
      FROM video_metrics m
      INNER JOIN videos v ON v.id = m.video_id
    ''');
    final row = stats.first;
    return {
      'total_videos': totalVideos,
      'total_plays': (row['total_plays'] as int?) ?? 0,
      'total_likes': (row['total_likes'] as int?) ?? 0,
      'total_comments': (row['total_comments'] as int?) ?? 0,
      'total_shares': (row['total_shares'] as int?) ?? 0,
      'total_collects': (row['total_collects'] as int?) ?? 0,
      'avg_plays': (row['avg_plays'] as double?) ?? 0.0,
      'avg_likes': (row['avg_likes'] as double?) ?? 0.0,
      'avg_comments': (row['avg_comments'] as double?) ?? 0.0,
      'avg_shares': (row['avg_shares'] as double?) ?? 0.0,
      'avg_collects': (row['avg_collects'] as double?) ?? 0.0,
      'avg_finish_rate': (row['avg_finish_rate'] as double?) ?? 0.0,
      'avg_watch_duration': (row['avg_watch_duration'] as double?) ?? 0.0,
      'avg_cover_ctr': (row['avg_cover_ctr'] as double?) ?? 0.0,
      'avg_two_second_exit_rate': (row['avg_two_second_exit_rate'] as double?) ?? 0.0,
      'avg_five_second_finish_rate': (row['avg_five_second_finish_rate'] as double?) ?? 0.0,
      'total_profile_visits': (row['total_profile_visits'] as int?) ?? 0,
      'total_full_plays': (row['total_full_plays'] as int?) ?? 0,
      'traffic_recommend': (row['traffic_recommend'] as double?) ?? 0.0,
      'traffic_search': (row['traffic_search'] as double?) ?? 0.0,
      'traffic_follow': (row['traffic_follow'] as double?) ?? 0.0,
      'traffic_city': (row['traffic_city'] as double?) ?? 0.0,
    };
  }

  /// Get average traffic source distribution
  Future<Map<String, double>> getTrafficSourceAvg() async {
    final db = await AppDatabase.database;
    final result = await db.rawQuery('''
      SELECT 
        AVG(traffic_recommend) as recommend,
        AVG(traffic_search) as search,
        AVG(traffic_follow) as follow,
        AVG(traffic_city) as city
      FROM video_metrics
      WHERE traffic_recommend > 0 OR traffic_search > 0 OR traffic_follow > 0 OR traffic_city > 0
    ''');
    if (result.isEmpty) {
      return {'recommend': 0, 'search': 0, 'follow': 0, 'city': 0};
    }
    final row = result.first;
    return {
      'recommend': (row['recommend'] as double?) ?? 0,
      'search': (row['search'] as double?) ?? 0,
      'follow': (row['follow'] as double?) ?? 0,
      'city': (row['city'] as double?) ?? 0,
    };
  }

  // ========== CSV Imports ==========

  Future<int> recordCsvImport({
    required String fileName,
    required int importedAt,
    required int videoCount,
    required String fileHash,
  }) async {
    final db = await AppDatabase.database;
    return await db.insert('csv_imports', {
      'file_name': fileName,
      'imported_at': importedAt,
      'imported_count': videoCount,
      'file_hash': fileHash,
    });
  }

  Future<void> insertCsvImport(Map<String, dynamic> data) async {
    final db = await AppDatabase.database;
    await db.insert('csv_imports', {
      'file_name': data['file_name'] ?? '',
      'file_path': data['file_path'] ?? '',
      'row_count': data['row_count'] ?? 0,
      'imported_count': data['imported_count'] ?? 0,
      'skipped_count': data['skipped_count'] ?? 0,
      'imported_at': data['imported_at'] ?? 0,
    });
  }

  Future<List<Map<String, dynamic>>> getImportHistory() async {
    final db = await AppDatabase.database;
    return await db.query('csv_imports', orderBy: 'imported_at DESC');
  }

  Future<List<Map<String, dynamic>>> getCsvImportHistory() async {
    return await getImportHistory();
  }

  Future<Map<String, dynamic>?> findImportByHash(String fileHash) async {
    final db = await AppDatabase.database;
    final results = await db.query('csv_imports', where: 'file_hash = ?', whereArgs: [fileHash]);
    return results.isNotEmpty ? results.first : null;
  }

  // ========== Data Clear ==========

  Future<void> clearAllData() async {
    final db = await AppDatabase.database;
    await db.delete('video_metrics');
    await db.delete('videos');
    await db.delete('csv_imports');
  }

  Future<void> clearAll() async => clearAllData();

  Future<void> clearFeishuCache() async {
    final db = await AppDatabase.database;
    await db.delete('feishu_config', where: 'key = ?', whereArgs: ['token']);
  }

  // ========== 飞书配置 ==========

  Future<String?> getFeishuConfig(String key) async {
    final db = await AppDatabase.database;
    final results = await db.query('feishu_config', where: 'key = ?', whereArgs: [key]);
    return results.isNotEmpty ? results.first['value'] as String? : null;
  }

  Future<void> setFeishuConfig(String key, String value) async {
    final db = await AppDatabase.database;
    await db.insert('feishu_config', {'key': key, 'value': value}, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<Map<String, String>> getAllFeishuConfig() async {
    final db = await AppDatabase.database;
    final results = await db.query('feishu_config');
    final map = <String, String>{};
    for (final row in results) {
      map[row['key'] as String] = row['value'] as String;
    }
    return map;
  }

  Future<void> deleteFeishuConfig(String key) async {
    final db = await AppDatabase.database;
    await db.delete('feishu_config', where: 'key = ?', whereArgs: [key]);
  }

  // ========== 抖音授权存储 ==========

  Future<String?> getDouyinAuth(String key) async {
    final db = await AppDatabase.database;
    final results = await db.query('douyin_auth', where: 'key = ?', whereArgs: [key]);
    return results.isNotEmpty ? results.first['value'] as String? : null;
  }

  Future<void> setDouyinAuth(String key, String value) async {
    final db = await AppDatabase.database;
    await db.insert('douyin_auth', {
      'key': key, 'value': value,
      'updated_at': DateTime.now().millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> deleteDouyinAuth(String key) async {
    final db = await AppDatabase.database;
    await db.delete('douyin_auth', where: 'key = ?', whereArgs: [key]);
  }

  Future<void> close() async {
    final db = _db;
    if (db != null) {
      await db.close();
      _db = null;
    }
  }

  // ========== 安全审计日志 ==========

  Future<int> insertAuditLog({
    required int timestamp,
    required String level,
    String? eventType,
    required String message,
    String? metadata,
  }) async {
    final db = await AppDatabase.database;
    return await db.insert('audit_logs', {
      'timestamp': timestamp,
      'level': level,
      'event_type': eventType,
      'message': message,
      'metadata': metadata,
    });
  }

  Future<List<Map<String, dynamic>>> getAuditLogs({
    int limit = 100,
    String? eventType,
    String? level,
  }) async {
    final db = await AppDatabase.database;
    var query = 'SELECT * FROM audit_logs WHERE 1=1';
    final args = <dynamic>[];
    if (eventType != null) {
      query += ' AND event_type = ?';
      args.add(eventType);
    }
    if (level != null) {
      query += ' AND level = ?';
      args.add(level);
    }
    query += ' ORDER BY timestamp DESC LIMIT ?';
    args.add(limit);
    return await db.rawQuery(query, args);
  }

  Future<int> clearAuditLogs({int olderThanDays = 30}) async {
    final db = await AppDatabase.database;
    final cutoff = DateTime.now()
        .subtract(Duration(days: olderThanDays))
        .millisecondsSinceEpoch;
    return await db.delete('audit_logs',
        where: 'timestamp < ?', whereArgs: [cutoff]);
  }

  // ========== 安全配置 ==========

  Future<String?> getSecurityConfig(String key) async {
    final db = await AppDatabase.database;
    final results =
        await db.query('security_config', where: 'key = ?', whereArgs: [key]);
    return results.isNotEmpty ? results.first['value'] as String? : null;
  }

  Future<void> setSecurityConfig(String key, String value) async {
    final db = await AppDatabase.database;
    await db.insert(
      'security_config',
      {
        'key': key,
        'value': value,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteSecurityConfig(String key) async {
    final db = await AppDatabase.database;
    await db.delete('security_config', where: 'key = ?', whereArgs: [key]);
  }

  // ========== 敏感字段加密存储 ==========

  /// 加密存储敏感数据（如 API Key 备份）
  Future<void> setEncryptedConfig(String key, String value) async {
    final encrypted = await SecurityService.instance.encryptPersistent(value);
    await setSecurityConfig('encrypted_$key', encrypted);
  }

  /// 解密读取敏感数据
  Future<String?> getEncryptedConfig(String key) async {
    final encrypted = await getSecurityConfig('encrypted_$key');
    if (encrypted == null) return null;
    return await SecurityService.instance.decryptPersistent(encrypted);
  }
}
