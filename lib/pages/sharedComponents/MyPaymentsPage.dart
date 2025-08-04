import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'appDrawer.dart';


class MyPaymentsPage extends StatelessWidget {
  const MyPaymentsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final weekStart = DateTime(now.year, now.month, now.day - (now.weekday - 1));
    final weekEnd = DateTime(weekStart.year, weekStart.month, weekStart.day + 6, 23, 59, 59, 999);
    final monthStart = DateTime(now.year, now.month, 1);

    return Scaffold(
      appBar: AppBar(title: const Text('Ödemelerim')),
      drawer: const AppDrawer(role: 'teacher'),
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