import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'appDrawer.dart';
import '../../service/notification_service.dart';

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
      appBar: AppBar(
        centerTitle: true,
        title: const Text(
          'Haftalık Program',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      drawer: const AppDrawer(role: 'teacher'),
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
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 2,
                child: ExpansionTile(
                  initiallyExpanded: day == today,
                  tilePadding: const EdgeInsets.symmetric(horizontal: 16),
                  childrenPadding: const EdgeInsets.only(bottom: 8),
                  title: Text(
                    dayNames[day]!,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: day == today ? Colors.deepPurple : Colors.black87,
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

                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        color: isPast ? Colors.grey[200] : Colors.white,
                        child: ListTile(
                          leading: const Icon(Icons.school, color: Colors.deepPurple),
                          title: Text(
                            lesson['stuName'],
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text('Saat: $timeStr$fee$statusText'),
                          trailing: IconButton(
                            icon: const Icon(Icons.cancel, color: Colors.red),
                            tooltip: "İptal Et",
                            onPressed: () async {
                              final isRecurrent = lesson['isRecurrent'] == true;
                              final result = await showDialog<String>(
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
                        onPressed: () async {
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
                                          const Flexible(
                                            child: Text("Tekrarlayan Ders (1 Yıl)", overflow: TextOverflow.ellipsis),
                                          ),
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
                      ),
                    ),
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
