import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:household_ledger/model/push_notification_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// 알림 예약 패턴이다. 새 패턴이 필요하면 여기에 추가하고 스케줄 분기만 확장한다.
enum PushSchedulePattern { daily, monthly, inactivity }

/// 예약할 알림 한 건의 변하지 않는 정의다.
class PushMessageDefinition {
  const PushMessageDefinition({
    required this.id,
    required this.category,
    required this.pattern,
    required this.bodyKey,
    required this.fallbackBody,
    required this.hour,
    this.minute = 0,
    this.dayOfMonth,
  });

  final int id;
  final PushNotificationCategory category;
  final PushSchedulePattern pattern;
  final String bodyKey;
  final String fallbackBody;
  final int hour;
  final int minute;
  final int? dayOfMonth;
}

/// 시스템 권한 요청과 카테고리별 로컬 알림 예약을 담당한다.
class PushMessageService {
  PushMessageService({FlutterLocalNotificationsPlugin? notifications})
    : _notifications = notifications ?? FlutterLocalNotificationsPlugin();

  static const String _permissionRequestedKey =
      'push_notification_permission_requested';
  static const int inactivityNotificationId = 1601;

  static const List<PushMessageDefinition> definitions =
      <PushMessageDefinition>[
        PushMessageDefinition(
          id: 1101,
          category: PushNotificationCategory.other,
          pattern: PushSchedulePattern.monthly,
          dayOfMonth: 1,
          hour: 9,
          bodyKey: 'pushMessageMonthlyEncouragement',
          fallbackBody: '이번달도 가계부를 열심히 기록해 볼까요??',
        ),
        PushMessageDefinition(
          id: 1201,
          category: PushNotificationCategory.fixedExpense,
          pattern: PushSchedulePattern.monthly,
          dayOfMonth: 15,
          hour: 9,
          bodyKey: 'pushMessageFixedExpense',
          fallbackBody: '이번달 전기세, 가스비, 휴대전화비용 등을 알려주실 시간이에요.',
        ),
        PushMessageDefinition(
          id: 1301,
          category: PushNotificationCategory.salary,
          pattern: PushSchedulePattern.monthly,
          hour: 9,
          bodyKey: 'pushMessageSalaryDay',
          fallbackBody: '급여일이네요! 이번달 수입도 알려주시겠어요?',
        ),
        PushMessageDefinition(
          id: 1401,
          category: PushNotificationCategory.daily,
          pattern: PushSchedulePattern.daily,
          hour: 13,
          bodyKey: 'pushMessageDailyLunch',
          fallbackBody: '오늘은 어떤걸 드셨나요? 기록을 남겨주시면 제가 분석해 드릴게요!',
        ),
        PushMessageDefinition(
          id: 1402,
          category: PushNotificationCategory.daily,
          pattern: PushSchedulePattern.daily,
          hour: 20,
          bodyKey: 'pushMessageDailyEvening',
          fallbackBody: '오늘 하루도 고생하셨어요~! 오늘의 소비, 저에게 남겨주세요 :)',
        ),
      ];

  final FlutterLocalNotificationsPlugin _notifications;
  bool _initialized = false;

  Future<void> initialize({required String localeCode}) async {
    if (_initialized) return;

    const android = AndroidInitializationSettings('ic_stat_household_ledger');
    const darwin = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    await _notifications.initialize(
      settings: const InitializationSettings(
        android: android,
        iOS: darwin,
        macOS: darwin,
      ),
    );

    tz_data.initializeTimeZones();
    try {
      final timezone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timezone.identifier));
    } catch (_) {
      tz.setLocalLocation(
        tz.getLocation(localeCode == 'jp' ? 'Asia/Tokyo' : 'Asia/Seoul'),
      );
    }
    _initialized = true;
  }

  /// 최초 한 번만 시스템 권한을 요청한다. 이미 요청했다면 null을 반환한다.
  Future<bool?> requestPermissionOnFirstLaunch() async {
    final preferences = await SharedPreferences.getInstance();
    if (preferences.getBool(_permissionRequestedKey) ?? false) return null;
    final granted = await areNotificationsEnabled()
        ? true
        : await requestPermission();
    await preferences.setBool(_permissionRequestedKey, true);
    return granted;
  }

  Future<bool> requestPermission() async {
    if (kIsWeb) return false;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return await _notifications
                .resolvePlatformSpecificImplementation<
                  AndroidFlutterLocalNotificationsPlugin
                >()
                ?.requestNotificationsPermission() ??
            true;
      case TargetPlatform.iOS:
        return await _notifications
                .resolvePlatformSpecificImplementation<
                  IOSFlutterLocalNotificationsPlugin
                >()
                ?.requestPermissions(alert: true, badge: true, sound: true) ??
            false;
      case TargetPlatform.macOS:
        return await _notifications
                .resolvePlatformSpecificImplementation<
                  MacOSFlutterLocalNotificationsPlugin
                >()
                ?.requestPermissions(alert: true, badge: true, sound: true) ??
            false;
      case TargetPlatform.fuchsia:
      case TargetPlatform.linux:
      case TargetPlatform.windows:
        return true;
    }
  }

  Future<bool> areNotificationsEnabled() async {
    if (kIsWeb) return false;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return await _notifications
                .resolvePlatformSpecificImplementation<
                  AndroidFlutterLocalNotificationsPlugin
                >()
                ?.areNotificationsEnabled() ??
            true;
      case TargetPlatform.iOS:
        final status = await _notifications
            .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin
            >()
            ?.checkPermissions();
        return status?.isEnabled ?? false;
      case TargetPlatform.macOS:
        final status = await _notifications
            .resolvePlatformSpecificImplementation<
              MacOSFlutterLocalNotificationsPlugin
            >()
            ?.checkPermissions();
        return status?.isEnabled ?? false;
      case TargetPlatform.fuchsia:
      case TargetPlatform.linux:
      case TargetPlatform.windows:
        return true;
    }
  }

  /// 현재 설정에 맞춰 반복 예약을 전부 재구성한다.
  Future<void> syncRecurringSchedules({
    required PushNotificationSettings settings,
    required Map<String, String> strings,
    required String localeCode,
  }) async {
    await initialize(localeCode: localeCode);
    await _cancelManagedNotifications(includeInactivity: false);
    if (!settings.enabled ||
        !settings.isCategoryEnabled(PushNotificationCategory.other)) {
      await cancelInactivityReminder();
    }
    if (!settings.enabled || !await areNotificationsEnabled()) return;

    for (final definition in definitions) {
      if (!settings.isCategoryEnabled(definition.category)) continue;
      await _scheduleDefinition(definition, settings, strings);
    }
  }

  /// 앱이 백그라운드로 갈 때 마지막 실행 기준 2일 알림을 다시 예약한다.
  Future<void> refreshInactivityReminder({
    required PushNotificationSettings settings,
    required Map<String, String> strings,
    required String localeCode,
  }) async {
    await initialize(localeCode: localeCode);
    await _notifications.cancel(id: inactivityNotificationId);
    if (!settings.enabled ||
        !settings.isCategoryEnabled(PushNotificationCategory.other) ||
        !await areNotificationsEnabled()) {
      return;
    }
    await _notifications.zonedSchedule(
      id: inactivityNotificationId,
      title: strings['pushNotificationTitle'] ?? '가계부 알림',
      body:
          strings['pushMessageInactivity'] ??
          '혹시 저를 잊으신건 아니시죠..? 까먹으셨다면 지금 바로 가계부 작성하러 Go~',
      scheduledDate: tz.TZDateTime.now(tz.local).add(const Duration(days: 2)),
      notificationDetails: _details(PushNotificationCategory.other, strings),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      payload: 'inactivity',
    );
  }

  /// 앱이 다시 열리면 미실행 알림은 더 이상 필요하지 않으므로 취소한다.
  Future<void> cancelInactivityReminder() async {
    await _notifications.cancel(id: inactivityNotificationId);
  }

  Future<void> cancelAllManagedNotifications() async {
    await _cancelManagedNotifications(includeInactivity: true);
  }

  Future<void> _cancelManagedNotifications({
    required bool includeInactivity,
  }) async {
    for (final definition in definitions) {
      await _notifications.cancel(id: definition.id);
    }
    if (includeInactivity) {
      await _notifications.cancel(id: inactivityNotificationId);
    }
  }

  Future<void> _scheduleDefinition(
    PushMessageDefinition definition,
    PushNotificationSettings settings,
    Map<String, String> strings,
  ) async {
    final now = tz.TZDateTime.now(tz.local);
    final tz.TZDateTime scheduledDate;
    final DateTimeComponents components;
    switch (definition.pattern) {
      case PushSchedulePattern.daily:
        scheduledDate = _nextDaily(now, definition.hour, definition.minute);
        components = DateTimeComponents.time;
      case PushSchedulePattern.monthly:
        final day = definition.category == PushNotificationCategory.salary
            ? settings.salaryDay
            : definition.dayOfMonth!;
        scheduledDate = _nextMonthly(
          now,
          day,
          definition.hour,
          definition.minute,
        );
        components = DateTimeComponents.dayOfMonthAndTime;
      case PushSchedulePattern.inactivity:
        return;
    }

    await _notifications.zonedSchedule(
      id: definition.id,
      title: strings['pushNotificationTitle'] ?? '가계부 알림',
      body: strings[definition.bodyKey] ?? definition.fallbackBody,
      scheduledDate: scheduledDate,
      notificationDetails: _details(definition.category, strings),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: components,
      payload: definition.category.code,
    );
  }

  tz.TZDateTime _nextDaily(tz.TZDateTime now, int hour, int minute) {
    var result = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );
    if (!result.isAfter(now)) result = result.add(const Duration(days: 1));
    return result;
  }

  tz.TZDateTime _nextMonthly(tz.TZDateTime now, int day, int hour, int minute) {
    var result = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      day,
      hour,
      minute,
    );
    if (!result.isAfter(now)) {
      result = tz.TZDateTime(
        tz.local,
        now.year,
        now.month + 1,
        day,
        hour,
        minute,
      );
    }
    return result;
  }

  NotificationDetails _details(
    PushNotificationCategory category,
    Map<String, String> strings,
  ) {
    final channelId = 'ledger_${category.code}_notifications';
    final channelName = switch (category) {
      PushNotificationCategory.daily =>
        strings['pushCategoryDaily'] ?? 'Daily reminders',
      PushNotificationCategory.fixedExpense =>
        strings['pushCategoryFixedExpense'] ?? 'Fixed expense reminders',
      PushNotificationCategory.salary =>
        strings['pushCategorySalary'] ?? 'Salary reminders',
      PushNotificationCategory.other =>
        strings['pushCategoryOther'] ?? 'Other reminders',
    };
    return NotificationDetails(
      android: AndroidNotificationDetails(
        channelId,
        channelName,
        channelDescription:
            strings['pushMasterDescription'] ??
            'Household Ledger scheduled reminders',
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: DarwinNotificationDetails(threadIdentifier: category.code),
      macOS: DarwinNotificationDetails(threadIdentifier: category.code),
    );
  }
}

final pushMessageServiceProvider = Provider<PushMessageService>((Ref ref) {
  return PushMessageService();
});
