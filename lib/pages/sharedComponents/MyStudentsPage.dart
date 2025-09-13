import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'appDrawer.dart';
import 'package:firebase_auth/firebase_auth.dart';

class MyStudentsPage extends StatelessWidget {
  const MyStudentsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Öğrencilerim')),
      drawer: const AppDrawer(role: 'teacher'),
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
              'uid': FirebaseAuth.instance.currentUser!.uid,
            });
          }
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}