import 'dart:io';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart';

class LocalNotificationService {
  static final LocalNotificationService _instance = LocalNotificationService._internal();
  factory LocalNotificationService() => _instance;
  LocalNotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;

  /// Initialize the notification service
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Android initialization settings
      const AndroidInitializationSettings androidSettings =
          AndroidInitializationSettings('@mipmap/ic_launcher');

      // iOS initialization settings
      const DarwinInitializationSettings iosSettings = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      // Windows initialization settings (optional, may not be available in all versions)
      final InitializationSettings initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
        macOS: iosSettings,
      );

      final bool? initialized = await _notifications.initialize(
        initSettings,
        onDidReceiveNotificationResponse: _onNotificationTapped,
      );

      if (initialized == true) {
        _isInitialized = true;
        print('✅ Local notifications initialized successfully');
      } else {
        print('⚠️ Local notifications initialization returned false');
      }

      // Request permissions for Android 13+
      if (Platform.isAndroid) {
        await _requestAndroidPermissions();
      }

      // Request permissions for iOS
      if (Platform.isIOS) {
        await _requestIOSPermissions();
      }
    } catch (e) {
      print('❌ Error initializing local notifications: $e');
    }
  }

  /// Request Android permissions (Android 13+)
  Future<void> _requestAndroidPermissions() async {
    if (Platform.isAndroid) {
      final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
          _notifications.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();

      if (androidImplementation != null) {
        final bool? granted = await androidImplementation.requestNotificationsPermission();
        if (granted == true) {
          print('✅ Android notification permission granted');
        } else {
          print('⚠️ Android notification permission denied');
        }
      }
    }
  }

  /// Request iOS permissions
  Future<void> _requestIOSPermissions() async {
    if (Platform.isIOS) {
      try {
        final iosImplementation =
            _notifications.resolvePlatformSpecificImplementation<
                IOSFlutterLocalNotificationsPlugin>();
        
        if (iosImplementation != null) {
          final bool? granted = await iosImplementation.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          );
          if (granted == true) {
            print('✅ iOS notification permission granted');
          } else {
            print('⚠️ iOS notification permission denied');
          }
        }
      } catch (e) {
        // For newer versions, permissions are requested during initialization
        // If IOSFlutterLocalNotificationsPlugin doesn't exist, skip permission request
        print('⚠️ Could not request iOS permissions: $e');
        print('ℹ️ iOS permissions will be requested during initialization');
      }
    }
  }

  /// Show a low stock notification
  Future<void> showLowStockNotification({
    required int productId,
    required String productName,
    required double currentStock,
    required double reorderLevel,
  }) async {
    if (!_isInitialized) {
      await initialize();
    }

    try {
      const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        'low_stock_channel',
        'Low Stock Alerts',
        channelDescription: 'Notifications for products with low stock levels',
        importance: Importance.high,
        priority: Priority.high,
        showWhen: true,
        enableVibration: true,
        playSound: true,
      );

      const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      const NotificationDetails notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
        macOS: iosDetails,
      );

      final String title = 'Low Stock Alert';
      final String body =
          '$productName is running low!\nCurrent: ${currentStock.toStringAsFixed(0)} | Reorder Level: ${reorderLevel.toStringAsFixed(0)}';

      await _notifications.show(
        productId, // Use product ID as notification ID to avoid duplicates
        title,
        body,
        notificationDetails,
        payload: 'product_$productId',
      );

      print('✅ Low stock notification sent for: $productName');
    } catch (e) {
      print('❌ Error showing low stock notification: $e');
    }
  }

  /// Show multiple low stock products notification
  Future<void> showMultipleLowStockNotification(int count) async {
    if (!_isInitialized) {
      await initialize();
    }

    if (count == 0) return;

    try {
      const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        'low_stock_channel',
        'Low Stock Alerts',
        channelDescription: 'Notifications for products with low stock levels',
        importance: Importance.high,
        priority: Priority.high,
        showWhen: true,
        enableVibration: true,
        playSound: true,
        styleInformation: BigTextStyleInformation(''),
      );

      const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      const NotificationDetails notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
        macOS: iosDetails,
      );

      final String title = 'Low Stock Alert';
      final String body = count == 1
          ? '1 product is running low on stock'
          : '$count products are running low on stock';

      await _notifications.show(
        999999, // Special ID for multiple products notification
        title,
        body,
        notificationDetails,
        payload: 'low_stock_multiple',
      );

      print('✅ Multiple low stock notification sent for $count products');
    } catch (e) {
      print('❌ Error showing multiple low stock notification: $e');
    }
  }

  /// Cancel a specific notification
  Future<void> cancelNotification(int id) async {
    await _notifications.cancel(id);
  }

  /// Cancel all notifications
  Future<void> cancelAllNotifications() async {
    await _notifications.cancelAll();
  }

  /// Handle notification tap
  void _onNotificationTapped(NotificationResponse response) {
    print('Notification tapped: ${response.payload}');
    // You can navigate to a specific screen based on payload
    // For example: if (response.payload?.startsWith('product_') == true) { ... }
  }

  /// Check if notifications are enabled
  Future<bool> areNotificationsEnabled() async {
    if (Platform.isAndroid) {
      final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
          _notifications.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      if (androidImplementation != null) {
        return await androidImplementation.areNotificationsEnabled() ?? false;
      }
    }
    // For iOS and Windows, assume enabled if initialized
    return _isInitialized;
  }
}

