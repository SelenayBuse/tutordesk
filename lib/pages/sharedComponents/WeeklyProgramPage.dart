import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'appDrawer.dart';
import '../../service/notification_service.dart';

class WeeklyProgramPage extends StatefulWidget {
  const WeeklyProgramPage({super.key});

  @override
  State<WeeklyProgramPage> createState() => _WeeklyProgramPageState();
}

class _WeeklyProgramPageState extends State<WeeklyProgramPage> {
  /// 0 = bu hafta, 1 = sonraki, 2 = ondan sonraki (maks +2)
  int weekOffset = 0;

  DateTime _mondayOfWeek(DateTime base) {
    final monday = base.subtract(Duration(days: base.weekday - 1));
    return DateTime(monday.year, monday.month, monday.day);
  }

  /// Seçili `weekOffset` için [start, end] döner.
  List<DateTime> _boundsForOffset(int offset) {
    final today = DateTime.now();
    final start = _mondayOfWeek(today).add(Duration(days: 7 * offset));
    final end = start.add(const Duration(days: 6, hours: 23, minutes: 59, seconds: 59, milliseconds: 999));
    return [start, end];
  }

  static const Map<int, String> _dayNames = {
    1: "Pazartesi",
    2: "Salı",
    3: "Çarşamba",
    4: "Perşembe",
    5: "Cuma",
    6: "Cumartesi",
    7: "Pazar",
  };

  String _dayLabelWithDate(DateTime weekStart, int dayIndex) {
    final date = weekStart.add(Duration(days: dayIndex - 1));
    final d = DateFormat('dd.MM').format(date);
    return "${_dayNames[dayIndex]}  •  $d";
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return const Scaffold(
        body: Center(child: Text('Devam etmek için lütfen giriş yapın.')),
      );
    }

    final bounds = _boundsForOffset(weekOffset);
    final start = bounds[0];
    final end = bounds[1];
    final isThisWeek = weekOffset == 0;
    final todayWeekday = DateTime.now().weekday;

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text('Haftalık Program', style: TextStyle(fontWeight: FontWeight.w600)),
        actions: [
          if (weekOffset > 0)
            IconButton(
              tooltip: 'Bu haftaya dön',
              icon: const Icon(Icons.chevron_left),
              onPressed: () => setState(() => weekOffset--),
            ),
          IconButton(
            tooltip: 'Sonraki hafta',
            icon: const Icon(Icons.chevron_right),
            onPressed: weekOffset >= 2 ? null : () => setState(() => weekOffset++),
          ),
        ],
      ),
      drawer: const AppDrawer(role: 'teacher'),
      body: StreamBuilder<QuerySnapshot>(
        // *** YALNIZCA uid eşitliği —> index gerektirmez
        stream: FirebaseFirestore.instance
            .collection('lessons')
            .where('uid', isEqualTo: uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('Dersler yüklenirken hata oluştu: ${snapshot.error}', textAlign: TextAlign.center),
              ),
            );
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          // --- Lokalde filtreleme + sıralama ---
          final now = DateTime.now();
          final allDocs = snapshot.data?.docs ?? [];

          // Sadece bu haftanın derslerini al:
          final weekDocs = allDocs.where((d) {
            final ts = d['lessonDate'];
            if (ts is! Timestamp) return false;
            final dt = ts.toDate();
            return !dt.isBefore(start) && !dt.isAfter(end);
          }).toList();

          // Tarihe göre sırala (artan)
          weekDocs.sort((a, b) {
            final ad = (a['lessonDate'] as Timestamp).toDate();
            final bd = (b['lessonDate'] as Timestamp).toDate();
            return ad.compareTo(bd);
          });

          // Güne göre grupla
          final Map<int, List<QueryDocumentSnapshot>> grouped = {};
          for (final doc in weekDocs) {
            final dt = (doc['lessonDate'] as Timestamp).toDate();
            final day = dt.weekday;
            grouped.putIfAbsent(day, () => []).add(doc);
          }

          return ListView.builder(
            itemCount: 7,
            itemBuilder: (context, index) {
              final day = index + 1; // 1..7
              final dayLessons = grouped[day] ?? [];

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 2,
                child: ExpansionTile(
                  initiallyExpanded: isThisWeek && day == todayWeekday,
                  tilePadding: const EdgeInsets.symmetric(horizontal: 16),
                  childrenPadding: const EdgeInsets.only(bottom: 8),
                  title: Text(
                    _dayLabelWithDate(start, day),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: (isThisWeek && day == todayWeekday) ? Colors.deepPurple : Colors.black87,
                    ),
                  ),
                  children: [
                    ...dayLessons.map((doc) {
                      final lesson = doc.data() as Map<String, dynamic>;
                      final dateTime = (lesson['lessonDate'] as Timestamp).toDate();
                      final timeStr = DateFormat('HH:mm').format(dateTime);
                      final fee = lesson['fee'] != null ? " | Ücret: ${lesson['fee']}₺" : "";
                      final isPast = dateTime.isBefore(now);
                      final isPaid = (lesson['isPaid'] ?? false) == true;
                      final statusText = isPast ? (isPaid ? " (Ödendi)" : " (Ödenmedi)") : "";

                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        color: isPast ? Colors.grey[200] : Colors.white,
                        child: ListTile(
                          leading: const Icon(Icons.school, color: Colors.deepPurple),
                          title: Text(lesson['stuName'] ?? '-', style: const TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: Text('Saat: $timeStr$fee$statusText'),
                          trailing: IconButton(
                            icon: const Icon(Icons.cancel, color: Colors.red),
                            tooltip: "İptal Et",
                            onPressed: () async {
                              final isRecurrent = (lesson['isRecurrent'] ?? false) == true;
                              final decision = await showDialog<String>(
                                context: context,
                                builder: (context) => AlertDialog(
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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

                              if (decision == null) return;

                              if (decision == 'single') {
                                await FirebaseFirestore.instance.collection('lessons').doc(doc.id).delete();
                              } else if (decision == 'future') {
                                final lessonDate = (lesson['lessonDate'] as Timestamp).toDate();
                                final stuName = (lesson['stuName'] ?? '').toString();

                                // *** Indexsiz: sadece uid ile çek, gerisini lokalde filtrele
                                final allUserLessons = await FirebaseFirestore.instance
                                    .collection('lessons')
                                    .where('uid', isEqualTo: uid)
                                    .get();

                                for (final ldoc in allUserLessons.docs) {
                                  final ldata = ldoc.data() as Map<String, dynamic>;
                                  final isRec = (ldata['isRecurrent'] ?? false) == true;
                                  final nameOk = (ldata['stuName'] ?? '') == stuName;
                                  final dt = (ldata['lessonDate'] as Timestamp).toDate();
                                  if (isRec && nameOk && !dt.isBefore(lessonDate)) {
                                    await ldoc.reference.delete();
                                  }
                                }
                              }
                            },
                          ),
                        ),
                      );
                    }),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.add),
                        label: const Text("Ders Ekle"),
                        style: ElevatedButton.styleFrom(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          backgroundColor: Colors.deepPurple,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(double.infinity, 48),
                        ),
                        onPressed: () => _onAddLessonPressed(context, uid, start, day),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _onAddLessonPressed(
    BuildContext context,
    String uid,
    DateTime weekStart,
    int day, // 1..7
  ) async {
    // *** Indexsiz: sadece uid ile çek, isim sıralamasını lokalde yap
    final studentsSnapshot = await FirebaseFirestore.instance
        .collection('students')
        .where('uid', isEqualTo: uid)
        .get();

    final students = studentsSnapshot.docs
        .map((doc) => doc.data() as Map<String, dynamic>)
        .toList()
      ..sort((a, b) => (a['stuName'] ?? '').toString().compareTo((b['stuName'] ?? '').toString()));

    String? selectedStudent;
    TimeOfDay selectedTime = TimeOfDay.now();
    bool isRecurrent = false;

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
                            value: (stu['stuName'] ?? '').toString(),
                            child: Text((stu['stuName'] ?? '').toString()),
                          ))
                      .toList(),
                  onChanged: (value) => setState(() => selectedStudent = value),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Text("Saat: "),
                    TextButton(
                      child: Text(selectedTime.format(context)),
                      onPressed: () async {
                        final picked = await showTimePicker(
                          context: context,
                          initialTime: selectedTime,
                        );
                        if (picked != null) setState(() => selectedTime = picked);
                      },
                    ),
                  ],
                ),
                Row(
                  children: [
                    Checkbox(
                      value: isRecurrent,
                      onChanged: (value) => setState(() => isRecurrent = value ?? false),
                    ),
                    const Flexible(
                      child: Text("Tekrarlayan Ders (1 Yıl)", overflow: TextOverflow.ellipsis),
                    ),
                  ],
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text("Vazgeç")),
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

    if (result == null) return;

    final selectedStu = students.firstWhere(
      (s) => (s['stuName'] ?? '').toString() == result['stuName'],
      orElse: () => <String, dynamic>{},
    );
    final fee = selectedStu['fee'] ?? 0;

    final dayDate = weekStart.add(Duration(days: day - 1));
    final baseDate = DateTime(
      dayDate.year,
      dayDate.month,
      dayDate.day,
      result['time'].hour,
      result['time'].minute,
    );

    Future<void> _createOne(DateTime when) async {
      final docRef = await FirebaseFirestore.instance.collection('lessons').add({
        'uid': uid, // sahiplik alanı (rules için)
        'stuName': result['stuName'],
        'fee': fee,
        'lessonDate': Timestamp.fromDate(when),
        'isPaid': false,
        'isRecurrent': result['isRecurrent'] == true,
      });

      final id = when.millisecondsSinceEpoch ~/ 1000;
      await NotificationService().scheduleNotification(
        id: id,
        title: 'Ders Hatırlatması',
        body: '${result['stuName']} ile dersiniz başlamak üzere.',
        scheduledDate: when.subtract(const Duration(minutes: 10)),
      );
      await NotificationService().scheduleFollowUpNotification(
        id: id + 1,
        docId: docRef.id,
        stuName: result['stuName'],
        scheduledDate: when,
      );
    }

    if (result['isRecurrent'] == true) {
      for (int i = 0; i < 52; i++) {
        await _createOne(baseDate.add(Duration(days: i * 7)));
      }
    } else {
      await _createOne(baseDate);
    }
  }
}
