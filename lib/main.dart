import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:permission_handler/permission_handler.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await NotificationService().init();

  if (await Permission.notification.isDenied) {
    await Permission.notification.request();
  }

  runApp(const MyApp());
}

class NotificationService {
  static final _notifications = FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    tz.initializeTimeZones();

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');

    const settings = InitializationSettings(android: android);
    await _notifications.initialize(settings);
  }

  Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
  }) async {
    await _notifications.zonedSchedule(
      id,
      title,
      body,
      tz.TZDateTime.from(scheduledDate, tz.local),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'lesson_channel',
          'Lesson Reminders',
          importance: Importance.max,
          priority: Priority.high,
        ),
      ),
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
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
            color: const Color(0xFFEDE7F6), // Başlık alanı
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
          final upcoming = lessons.cast<QueryDocumentSnapshot>().firstWhere(
            (doc) => (doc['lessonDate'] as Timestamp).toDate().isAfter(now),
            orElse: () => lessons.first,
          );
          final upcomingTime = (upcoming['lessonDate'] as Timestamp).toDate();
          final upcomingStu = upcoming['stuName'];
          final upcomingStr = DateFormat('HH:mm').format(upcomingTime);

          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Card(
                  color: const Color(0xFFEDE7F6),
                  child: ListTile(
                    title: const Text('Sıradaki Ders', style: TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('$upcomingStu - $upcomingStr'),
                  ),
                ),
                const SizedBox(height: 12),
                const Text('Günlük Program', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                ...lessons.map((doc) {
                  final lesson = doc.data() as Map<String, dynamic>;
                  final dateTime = (lesson['lessonDate'] as Timestamp).toDate();
                  final isPast = dateTime.isBefore(now);
                  final timeStr = DateFormat('HH:mm').format(dateTime);
                  return Opacity(
                    opacity: isPast ? 0.4 : 1.0,
                    child: ListTile(
                      title: Text(lesson['stuName']),
                      subtitle: Text('Saat: $timeStr'),
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
      DateTime(end.year, end.month, end.day, 23, 59, 59, 999)
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
                    ...dayLessons.isEmpty
                        ? [const ListTile(title: Text("Ders yok"))]
                        : dayLessons.map((doc) {
                            final lesson = doc.data() as Map<String, dynamic>;
                            final dateTime = (lesson['lessonDate'] as Timestamp).toDate();
                            final timeStr = DateFormat('HH:mm').format(dateTime);
                            final fee = lesson['fee'] != null ? " | Ücret: ${lesson['fee']}₺" : "";
                            final isPast = dateTime.isBefore(now);

                            return Opacity(
                              opacity: isPast ? 0.4 : 1.0,
                              child: ListTile(
                                title: Text(lesson['stuName']),
                                subtitle: Text('Saat: $timeStr$fee'),
                                trailing: IconButton(
                                  icon: const Icon(Icons.cancel, color: Colors.red),
                                  tooltip: "İptal Et",
                                  onPressed: () async {
                                    final result = await showDialog<bool>(
                                      context: context,
                                      builder: (context) => AlertDialog(
                                        title: const Text("Dersi İptal Et"),
                                        content: const Text("Bu dersi silmek istiyor musun?"),
                                        actions: [
                                          TextButton(
                                            child: const Text("Vazgeç"),
                                            onPressed: () => Navigator.pop(context, false),
                                          ),
                                          ElevatedButton(
                                            child: const Text("Sil"),
                                            onPressed: () => Navigator.pop(context, true),
                                          ),
                                        ],
                                      ),
                                    );
                                    if (result == true) {
                                      await FirebaseFirestore.instance
                                          .collection('lessons')
                                          .doc(doc.id)
                                          .delete();
                                    }
                                  },
                                ),
                              ),
                            );
                          }).toList(),
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
                                  ],
                                ),
                                actions: [
                                  TextButton(
                                    child: const Text("Vazgeç"),
                                    onPressed: () => Navigator.pop(context),
                                  ),
                                  ElevatedButton(
                                    child: const Text("Ekle"),
                                    onPressed: () {
                                      if (selectedStudent != null) {
                                        Navigator.pop(context, {
                                          "stuName": selectedStudent,
                                          "time": selectedTime,
                                        });
                                      }
                                    },
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
                          final lessonDate = DateTime(
                            d.year,
                            d.month,
                            d.day,
                            result['time'].hour,
                            result['time'].minute,
                          );

                          await FirebaseFirestore.instance.collection('lessons').add({
                            'stuName': result['stuName'],
                            'fee': fee,
                            'lessonDate': Timestamp.fromDate(lessonDate),
                          });
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
              final stu = students[index].data() as Map<String, dynamic>;
              return ListTile(
                title: Text(stu['stuName'] ?? 'İsimsiz'),
                subtitle: stu['fee'] != null ? Text("Ücret: ${stu['fee']}₺") : null,
              );
            },
          );
        },
      ),
    );
  }
}

class PaymentsPage extends StatelessWidget {
  const PaymentsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ödemelerim')),
      drawer: const AppDrawer(),
      body: const Center(
        child: Text('Ödemeler sayfası henüz hazırlanmadı.'),
      ),
    );
  }
}
