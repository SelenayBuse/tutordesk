import 'sharedComponents/appDrawer.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';



class TeacherHomePage  extends StatelessWidget {
  const TeacherHomePage ({super.key});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final todayEnd = todayStart.add(const Duration(days: 1)).subtract(const Duration(milliseconds: 1));

    return Scaffold(
      appBar: AppBar(title: const Text('Ana Sayfa')),
      drawer: AppDrawer(role: 'teacher'),
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