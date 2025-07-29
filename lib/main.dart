import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:permission_handler/permission_handler.dart';
import 'dart:developer';
import 'dart:io';
import 'package:android_intent_plus/android_intent.dart';
import 'package:android_intent_plus/flag.dart';
import 'package:device_info_plus/device_info_plus.dart';


Future<void> requestExactAlarmPermission() async {
  if (Platform.isAndroid) {
    final androidInfo = await DeviceInfoPlugin().androidInfo;
    final sdkInt = androidInfo.version.sdkInt;
    if (sdkInt >= 31) {
      final intent = AndroidIntent(
        action: 'android.settings.REQUEST_SCHEDULE_EXACT_ALARM',
        flags: <int>[Flag.FLAG_ACTIVITY_NEW_TASK],
      );
      await intent.launch();
    }
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await NotificationService().init();

  if (await Permission.notification.isDenied) {
    await Permission.notification.request();
  }
    await requestExactAlarmPermission(); 
  runApp(const MyApp());
}

class NotificationService {
  static final _notifications = FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    tz.initializeTimeZones();

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initializationSettings = InitializationSettings(android: android);

    await _notifications.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (response) async {
        final payload = response.payload ?? '';
        final parts = payload.split('|');
        if (parts.length == 2) {
          final docId = parts[0];
          final stuName = parts[1];
          final action = response.actionId;

          final lessonDoc = FirebaseFirestore.instance.collection('lessons').doc(docId);
          final studentQuery = await FirebaseFirestore.instance
              .collection('students')
              .where('stuName', isEqualTo: stuName)
              .limit(1)
              .get();

          if (studentQuery.docs.isNotEmpty) {
            final studentDoc = studentQuery.docs.first;
            final studentId = studentDoc.id;
            final fee = studentDoc['fee'] ?? 0;

            if (action == 'evet') {
              await lessonDoc.update({'isPaid': true});
              await FirebaseFirestore.instance.collection('students').doc(studentId).update({
                'paidAmount': FieldValue.increment(fee),
              });
            } else if (action == 'hayir') {
              await lessonDoc.update({'isPaid': false});
              await FirebaseFirestore.instance.collection('students').doc(studentId).update({
                'unpaidAmount': FieldValue.increment(fee),
              });
            }
          }
        }
      },
    );
  }

  Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
  }) async {
    try {
      final tzDate = tz.TZDateTime.from(scheduledDate, tz.local);

      if (tzDate.isBefore(tz.TZDateTime.now(tz.local))) {
        debugPrint("🛑 Notification not scheduled — date is in the past: $tzDate");
        return;
      }

      debugPrint("⏰ Scheduling notification for: $tzDate");

      await _notifications.zonedSchedule(
        id,
        title,
        body,
        tzDate,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'lesson_channel',
            'Lesson Reminders',
            importance: Importance.max,
            priority: Priority.high,
          ),
        ),
        //androidAllowWhileIdle: true,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    } catch (e, st) {
      debugPrint("❌ Failed to schedule notification: $e\n$st");
    }  } 

  Future<void> scheduleFollowUpNotification({
    required int id,
    required String docId,
    required String stuName,
    required DateTime scheduledDate,
  }) async {
    final tzDate = tz.TZDateTime.from(scheduledDate.add(const Duration(hours: 1)), tz.local);
    if (tzDate.isBefore(tz.TZDateTime.now(tz.local))) return;

    await _notifications.zonedSchedule(
      id,
      'Ödeme Kontrolü',
      '$stuName ile dersinizin ödemesini aldınız mı?',
      tzDate,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'payment_check_channel',
          'Payment Check',
          importance: Importance.max,
          priority: Priority.high,
          actions: <AndroidNotificationAction>[
            AndroidNotificationAction('evet', 'Evet'),
            AndroidNotificationAction('hayir', 'Hayır'),
          ],
        ),
      ),
      payload: '$docId|$stuName',
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
    );
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ders Düzenleme',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const HomePage(),
    );
  }
}

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      width: 240,
      backgroundColor: const Color(0xFFF9F5FF), // Açık lila
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          Container(
            height: 120,
            padding: const EdgeInsets.only(left: 16, bottom: 12),
            alignment: Alignment.bottomLeft,
            color: const Color.fromARGB(255, 211, 192, 242), // Başlık alanı
            child: const Text(
              'Menü',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Colors.deepPurple,
              ),
            ),
          ),
          _drawerItem(Icons.calendar_today, 'Ana Sayfa', () {
            Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HomePage()));
          }),
          _drawerItem(Icons.calendar_view_week, 'Haftalık Program', () {
            Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const WeeklyProgramPage()));
          }),
          _drawerItem(Icons.person, 'Öğrencilerim', () {
            Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const StudentsPage()));
          }),
          _drawerItem(Icons.payment, 'Ödemelerim', () {
            Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const PaymentsPage()));
          }),
        ],
      ),
    );
  }

  Widget _drawerItem(IconData icon, String title, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: Colors.deepPurple),
      title: Text(
        title,
        style: const TextStyle(fontSize: 16, color: Colors.black87),
      ),
      onTap: onTap,
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final todayEnd = todayStart.add(const Duration(days: 1)).subtract(const Duration(milliseconds: 1));

    return Scaffold(
      appBar: AppBar(title: const Text('Ana Sayfa')),
      drawer: const AppDrawer(),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('lessons')
            .where('lessonDate', isGreaterThanOrEqualTo: Timestamp.fromDate(todayStart))
            .where('lessonDate', isLessThanOrEqualTo: Timestamp.fromDate(todayEnd))
            .orderBy('lessonDate')
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('Bugün için ders yok.'));
          }

          final lessons = snapshot.data!.docs;
          final now = DateTime.now();

          // En yakın gelecekteki dersi bul
          final futureLessons = lessons.where((doc) {
            final date = (doc['lessonDate'] as Timestamp).toDate();
            return date.isAfter(now);
          }).toList();

          Widget upcomingCard;
          if (futureLessons.isNotEmpty) {
            final upcoming = futureLessons.first;
            final upcomingTime = (upcoming['lessonDate'] as Timestamp).toDate();
            final upcomingStu = upcoming['stuName'];
            final upcomingStr = DateFormat('HH:mm').format(upcomingTime);

            upcomingCard = Card(
              color: const Color(0xFFEDE7F6),
              child: ListTile(
                title: const Text('Sıradaki Ders', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('$upcomingStu - $upcomingStr'),
              ),
            );
          } else {
            upcomingCard = const Card(
              color: Color(0xFFEDE7F6),
              child: ListTile(
                title: Text('Sıradaki Ders', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('Bugün için sıradaki ders kalmadı.'),
              ),
            );
          }

          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                upcomingCard,
                const SizedBox(height: 12),
                const Text('Günlük Program', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                ...lessons.map((doc) {
                  final lesson = doc.data() as Map<String, dynamic>;
                  final dateTime = (lesson['lessonDate'] as Timestamp).toDate();
                  final isPast = dateTime.isBefore(now);
                  final isPaid = lesson['isPaid'] ?? false;
                  final timeStr = DateFormat('HH:mm').format(dateTime);
                  final paymentStatus = isPast ? (isPaid ? " | Ödendi" : " | Ödenmedi") : "";

                  return Opacity(
                    opacity: isPast ? 0.4 : 1.0,
                    child: ListTile(
                      title: Text(lesson['stuName']),
                      subtitle: Text('Saat: $timeStr$paymentStatus'),
                      trailing: !isPast
                          ? IconButton(
                              icon: const Icon(Icons.cancel, color: Colors.red),
                              onPressed: () async {
                                final result = await showDialog<bool>(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: const Text("Dersi İptal Et"),
                                    content: const Text("Bu dersi silmek istediğine emin misin?"),
                                    actions: [
                                      TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Vazgeç")),
                                      ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text("Sil")),
                                    ],
                                  ),
                                );
                                if (result == true) {
                                  await FirebaseFirestore.instance.collection('lessons').doc(doc.id).delete();
                                }
                              },
                            )
                          : null,
                      onTap: () async {
                        if (isPast && isPaid == false) {
                          final confirmed = await showDialog<bool>(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text("Ödeme Alındı mı?"),
                              content: const Text("Bu dersin ödemesini aldınız mı?"),
                              actions: [
                                TextButton(
                                  child: const Text("Hayır"),
                                  onPressed: () => Navigator.pop(context, false),
                                ),
                                ElevatedButton(
                                  child: const Text("Evet"),
                                  onPressed: () => Navigator.pop(context, true),
                                ),
                              ],
                            ),
                          );

                          if (confirmed != null) {
                            final studentQuery = await FirebaseFirestore.instance
                                .collection('students')
                                .where('stuName', isEqualTo: lesson['stuName'])
                                .limit(1)
                                .get();

                            if (studentQuery.docs.isNotEmpty) {
                              final studentDoc = studentQuery.docs.first;
                              final studentId = studentDoc.id;
                              final fee = lesson['fee'] ?? 0;

                              await FirebaseFirestore.instance
                                  .collection('lessons')
                                  .doc(doc.id)
                                  .update({'isPaid': confirmed});

                              await FirebaseFirestore.instance
                                  .collection('students')
                                  .doc(studentId)
                                  .update({
                                confirmed ? 'paidAmount' : 'unpaidAmount': FieldValue.increment(fee),
                              });
                            }
                          }
                        }
                      },
                    ),
                  );
                }),
              ],
            ),
          );
        },
      ),
    );
  }
}



class WeeklyProgramPage extends StatelessWidget {
  const WeeklyProgramPage({super.key});

  List<DateTime> getThisWeekBounds() {
    final now = DateTime.now();
    final start = now.subtract(Duration(days: now.weekday - 1));
    final end = start.add(const Duration(days: 6, hours: 23, minutes: 59, seconds: 59));
    return [
      DateTime(start.year, start.month, start.day),
      DateTime(end.year, end.month, end.day, 23, 59, 59, 999),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final bounds = getThisWeekBounds();
    final today = DateTime.now().weekday;

    const dayNames = {
      1: "Pazartesi",
      2: "Salı",
      3: "Çarşamba",
      4: "Perşembe",
      5: "Cuma",
      6: "Cumartesi",
      7: "Pazar",
    };

    return Scaffold(
      appBar: AppBar(title: const Text('Haftalık Program')),
      drawer: const AppDrawer(),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('lessons')
            .where('lessonDate', isGreaterThanOrEqualTo: Timestamp.fromDate(bounds[0]))
            .where('lessonDate', isLessThanOrEqualTo: Timestamp.fromDate(bounds[1]))
            .orderBy('lessonDate')
            .snapshots(),
        builder: (context, snapshot) {
          final allDocs = snapshot.data?.docs ?? [];
          final Map<int, List<QueryDocumentSnapshot>> grouped = {};

          for (final doc in allDocs) {
            final dt = (doc['lessonDate'] as Timestamp).toDate();
            final day = dt.weekday;
            grouped.putIfAbsent(day, () => []).add(doc);
          }

          final now = DateTime.now();

          return ListView.builder(
            itemCount: 7,
            itemBuilder: (context, index) {
              final day = index + 1;
              final dayLessons = grouped[day] ?? [];

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: ExpansionTile(
                  initiallyExpanded: day == today,
                  title: Text(
                    dayNames[day]!,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: day == today ? Colors.deepPurple : null,
                    ),
                  ),
                  children: [
                    ...dayLessons.map((doc) {
                      final lesson = doc.data() as Map<String, dynamic>;
                      final dateTime = (lesson['lessonDate'] as Timestamp).toDate();
                      final timeStr = DateFormat('HH:mm').format(dateTime);
                      final fee = lesson['fee'] != null ? " | Ücret: ${lesson['fee']}₺" : "";
                      final isPast = dateTime.isBefore(now);
                      final isPaid = lesson['isPaid'] ?? false;
                      final statusText = isPast ? (isPaid ? " (Ödendi)" : " (Ödenmedi)") : "";

                      return Opacity(
                        opacity: isPast ? 0.4 : 1.0,
                        child: ListTile(
                          title: Text(lesson['stuName']),
                          subtitle: Text('Saat: $timeStr$fee$statusText'),
                          trailing: IconButton(
                            icon: const Icon(Icons.cancel, color: Colors.red),
                            tooltip: "İptal Et",
                            onPressed: () async {
                            final isRecurrent = lesson['isRecurrent'] == true;
                            final result = await showDialog<String>(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text("Dersi Sil"),
                                content: isRecurrent
                                    ? const Text("Bu ders tekrarlayan bir derstir.\n\nSadece bu dersi mi silmek istiyorsunuz yoksa bu ve gelecek tüm tekrarları mı?")
                                    : const Text("Bu dersi silmek istediğinize emin misiniz?"),
                                actions: [
                                  if (isRecurrent)
                                    TextButton(
                                      onPressed: () => Navigator.pop(context, 'single'),
                                      child: const Text("Sadece Bu Ders"),
                                    ),
                                  if (isRecurrent)
                                    ElevatedButton(
                                      onPressed: () => Navigator.pop(context, 'future'),
                                      child: const Text("Bu ve Gelecek Tüm Dersler"),
                                    ),
                                  if (!isRecurrent)
                                    ElevatedButton(
                                      onPressed: () => Navigator.pop(context, 'single'),
                                      child: const Text("Sil"),
                                    ),
                                  TextButton(
                                    onPressed: () => Navigator.pop(context, null),
                                    child: const Text("Vazgeç"),
                                  ),
                                ],
                              ),
                            );

                            if (result == 'single') {
                              await FirebaseFirestore.instance.collection('lessons').doc(doc.id).delete();
                              } else if (result == 'future') {

                                final lessonDate = (lesson['lessonDate'] as Timestamp).toDate();
                                final stuName = lesson['stuName'];

                                final futureLessons = await FirebaseFirestore.instance
                                    .collection('lessons')
                                    .where('stuName', isEqualTo: stuName)
                                    .where('isRecurrent', isEqualTo: true)
                                    .get();

                                for (final lessonDoc in futureLessons.docs) {
                                  final thisLessonDate = (lessonDoc['lessonDate'] as Timestamp).toDate();
                                  if (!thisLessonDate.isBefore(lessonDate)) {
                                    await lessonDoc.reference.delete();
                                  }
                                }
                              }
                            }
                          ),
                        ),
                      );
                    }),
                    const Divider(),
                    ListTile(
                      leading: const Icon(Icons.add),
                      title: const Text("Ders Ekle"),
                      onTap: () async {
                        final studentsSnapshot = await FirebaseFirestore.instance
                            .collection('students')
                            .orderBy('stuName')
                            .get();

                        final students = studentsSnapshot.docs
                            .map((doc) => doc.data() as Map<String, dynamic>)
                            .toList();

                        String? selectedStudent;
                        TimeOfDay selectedTime = TimeOfDay.now();
                        bool isRecurrent = false;

                        final result = await showDialog<Map<String, dynamic>>(
                          context: context,
                          builder: (context) {
                            return StatefulBuilder(
                              builder: (context, setState) => AlertDialog(
                                title: const Text("Ders Ekle"),
                                content: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    DropdownButtonFormField<String>(
                                      decoration: const InputDecoration(labelText: "Öğrenci Seç"),
                                      value: selectedStudent,
                                      isExpanded: true,
                                      items: students
                                          .map((stu) => DropdownMenuItem<String>(
                                                value: stu['stuName'],
                                                child: Text(stu['stuName']),
                                              ))
                                          .toList(),
                                      onChanged: (value) {
                                        setState(() {
                                          selectedStudent = value;
                                        });
                                      },
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        const Text("Saat: "),
                                        TextButton(
                                          child: Text("${selectedTime.format(context)}"),
                                          onPressed: () async {
                                            final picked = await showTimePicker(
                                              context: context,
                                              initialTime: selectedTime,
                                            );
                                            if (picked != null) {
                                              setState(() => selectedTime = picked);
                                            }
                                          },
                                        ),
                                      ],
                                    ),
                                    Row(
                                      children: [
                                        Checkbox(
                                          value: isRecurrent,
                                          onChanged: (value) {
                                            setState(() => isRecurrent = value ?? false);
                                          },
                                        ),
                                        const Text("Tekrarlayan Ders (1 Yıl)"),
                                      ],
                                    ),
                                  ],
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: const Text("Vazgeç"),
                                  ),
                                  ElevatedButton(
                                    onPressed: () {
                                      if (selectedStudent != null) {
                                        Navigator.pop(context, {
                                          "stuName": selectedStudent,
                                          "time": selectedTime,
                                          "isRecurrent": isRecurrent,
                                        });
                                      }
                                    },
                                    child: const Text("Ekle"),
                                  ),
                                ],
                              ),
                            );
                          },
                        );

                        if (result != null) {
                          final selectedStu = students.firstWhere((s) => s['stuName'] == result['stuName']);
                          final fee = selectedStu['fee'];
                          final d = bounds[0].add(Duration(days: day - 1));

                          final baseDate = DateTime(
                            d.year,
                            d.month,
                            d.day,
                            result['time'].hour,
                            result['time'].minute,
                          );

                          final isRecurrent = result['isRecurrent'] ?? false;

                          if (isRecurrent) {
                            for (int i = 0; i < 52; i++) {
                              final recurringDate = baseDate.add(Duration(days: i * 7));
                              final docRef = await FirebaseFirestore.instance.collection('lessons').add({
                                'stuName': result['stuName'],
                                'fee': fee,
                                'lessonDate': Timestamp.fromDate(recurringDate),
                                'isPaid': false,
                                'isRecurrent': true,
                              });

                              final id = recurringDate.millisecondsSinceEpoch ~/ 1000;
                              await NotificationService().scheduleNotification(
                                id: id,
                                title: 'Ders Hatırlatması',
                                body: '${result['stuName']} ile dersiniz başlamak üzere.',
                                scheduledDate: recurringDate.subtract(const Duration(minutes: 10)),
                              );
                              await NotificationService().scheduleFollowUpNotification(
                                id: id + 1,
                                docId: docRef.id,
                                stuName: result['stuName'],
                                scheduledDate: recurringDate,
                              );
                            }
                          } else {
                            final docRef = await FirebaseFirestore.instance.collection('lessons').add({
                              'stuName': result['stuName'],
                              'fee': fee,
                              'lessonDate': Timestamp.fromDate(baseDate),
                              'isPaid': false,
                              'isRecurrent': false,
                            });

                            final id = baseDate.millisecondsSinceEpoch ~/ 1000;
                            await NotificationService().scheduleNotification(
                              id: id,
                              title: 'Ders Hatırlatması',
                              body: '${result['stuName']} ile dersiniz başlamak üzere.',
                              scheduledDate: baseDate.subtract(const Duration(minutes: 10)),
                            );
                            await NotificationService().scheduleFollowUpNotification(
                              id: id + 1,
                              docId: docRef.id,
                              stuName: result['stuName'],
                              scheduledDate: baseDate,
                            );
                          }
                        }
                      },
                    )
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}


class StudentsPage extends StatelessWidget {
  const StudentsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Öğrencilerim')),
      drawer: const AppDrawer(),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('students').orderBy('stuName').snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text("Öğrenci bulunamadı."));
          }

          final students = snapshot.data!.docs;
          return ListView.builder(
            itemCount: students.length,
            itemBuilder: (context, index) {
              final doc = students[index];
              final stu = doc.data() as Map<String, dynamic>;
              final unpaid = stu['unpaidAmount'] ?? 0;

              return ListTile(
                title: Text(stu['stuName'] ?? 'İsimsiz'),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Tel: ${stu['stuPhone'] ?? '-'}"),
                    Text("Ücret: ${stu['fee']}₺"),
                    if (unpaid > 0) Text("Bekleyen Ödeme: $unpaid₺", style: const TextStyle(color: Colors.red)),
                  ],
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text("Öğrenciyi Sil"),
                        content: Text(
                          unpaid > 0
                              ? "Bu öğrenciden $unpaid₺ tutarında ödeme bekleniyor.\nSilmek istediğine emin misin?"
                              : "Bu öğrenciyi silmek istediğine emin misin?",
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text("Vazgeç"),
                          ),
                          ElevatedButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text("Sil"),
                          ),
                        ],
                      ),
                    );

                    if (confirm == true) {
                      await FirebaseFirestore.instance.collection('students').doc(doc.id).delete();
                    }
                  },
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final nameController = TextEditingController();
          final phoneController = TextEditingController();
          final feeController = TextEditingController();

          final result = await showDialog<bool>(
            context: context,
            builder: (context) {
              return AlertDialog(
                title: const Text("Öğrenci Ekle"),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(labelText: "Ad Soyad"),
                    ),
                    TextField(
                      controller: phoneController,
                      decoration: const InputDecoration(labelText: "Telefon"),
                      keyboardType: TextInputType.phone,
                    ),
                    TextField(
                      controller: feeController,
                      decoration: const InputDecoration(labelText: "Ders Ücreti (₺)"),
                      keyboardType: TextInputType.number,
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text("Vazgeç"),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      if (nameController.text.isNotEmpty &&
                          phoneController.text.isNotEmpty &&
                          feeController.text.isNotEmpty) {
                        Navigator.pop(context, true);
                      }
                    },
                    child: const Text("Ekle"),
                  ),
                ],
              );
            },
          );

          if (result == true) {
            final fee = int.tryParse(feeController.text.trim()) ?? 0;

            await FirebaseFirestore.instance.collection('students').add({
              'stuName': nameController.text.trim(),
              'stuPhone': phoneController.text.trim(),
              'fee': fee,
              'paidAmount': 0,
              'unpaidAmount': 0,
            });
          }
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}


class PaymentsPage extends StatelessWidget {
  const PaymentsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final weekStart = DateTime(now.year, now.month, now.day - (now.weekday - 1));
    final weekEnd = DateTime(weekStart.year, weekStart.month, weekStart.day + 6, 23, 59, 59, 999);
    final monthStart = DateTime(now.year, now.month, 1);

    return Scaffold(
      appBar: AppBar(title: const Text('Ödemelerim')),
      drawer: const AppDrawer(),
      body: FutureBuilder<List>(
        future: Future.wait([
          FirebaseFirestore.instance.collection('students').orderBy('stuName').get(),
          FirebaseFirestore.instance
              .collection('lessons')
              .where('lessonDate', isGreaterThanOrEqualTo: Timestamp.fromDate(weekStart))
              .where('lessonDate', isLessThanOrEqualTo: Timestamp.fromDate(weekEnd))
              .get(),
          FirebaseFirestore.instance
              .collection('lessons')
              .where('lessonDate', isGreaterThanOrEqualTo: Timestamp.fromDate(monthStart))
              .get(),
        ]),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final studentDocs = snapshot.data![0].docs;
          final weeklyLessons = snapshot.data![1].docs;
          final monthlyLessons = snapshot.data![2].docs;

          final totalWeeklyPaid = _sumFeesUsingStudents(
            lessons: weeklyLessons,
            students: studentDocs,
            isPaid: true,
          );
          final totalWeeklyUnpaid = _sumFeesUsingStudents(
            lessons: weeklyLessons,
            students: studentDocs,
            isPaid: false,
          );

          final totalMonthlyPaid = _sumFeesUsingStudents(
            lessons: monthlyLessons,
            students: studentDocs,
            isPaid: true,
          );
          final totalMonthlyUnpaid = _sumFeesUsingStudents(
            lessons: monthlyLessons,
            students: studentDocs,
            isPaid: false,
          );

          return ListView(
            padding: const EdgeInsets.all(12),
            children: [
              const Text('Öğrenciler', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              ...studentDocs.map((doc) {
                final stu = doc.data() as Map<String, dynamic>;
                final paid = stu['paidAmount'] ?? 0;
                final unpaid = stu['unpaidAmount'] ?? 0;
                return ListTile(
                  title: Text(stu['stuName']),
                  subtitle: Text("Ödenen: ${paid}₺ | Bekleyen: ${unpaid}₺"),
                );
              }),
              const Divider(thickness: 1.5),
              const SizedBox(height: 12),
              const Text('Bu Hafta', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              Text("Toplam Ödenen: ${totalWeeklyPaid}₺"),
              Text("Bekleyen: ${totalWeeklyUnpaid}₺"),
              const SizedBox(height: 16),
              const Text('Bu Ay', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              Text("Toplam Ödenen: ${totalMonthlyPaid}₺"),
              Text("Bekleyen: ${totalMonthlyUnpaid}₺"),
            ],
          );
        },
      ),
    );
  }

  int _sumFeesUsingStudents({
    required List<QueryDocumentSnapshot> lessons,
    required List<QueryDocumentSnapshot> students,
    required bool isPaid,
  }) {
    final Map<String, int> feeLookup = {
      for (var stu in students)
        (stu.data() as Map<String, dynamic>)['stuName']: (stu.data() as Map<String, dynamic>)['fee'] ?? 0
    };

    return lessons
        .where((doc) => doc['isPaid'] == isPaid)
        .map((doc) {
          final lesson = doc.data() as Map<String, dynamic>;
          final stuName = lesson['stuName'];
          return feeLookup[stuName] ?? 0;
        })
        .fold(0, (prev, fee) => prev + fee);
  }
}

