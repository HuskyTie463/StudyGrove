import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (snap.data == null) return const EmailAuthPage();
        return const TodayTasksPage();
      },
    );
  }
}

class EmailAuthPage extends StatefulWidget {
  const EmailAuthPage({super.key});
  @override
  State<EmailAuthPage> createState() => _EmailAuthPageState();
}

class _EmailAuthPageState extends State<EmailAuthPage> {
  final email = TextEditingController();
  final pass = TextEditingController();
  bool isRegister = false;
  bool loading = false;
  String err = '';

  Future<void> submit() async {
    setState(() { loading = true; err = ''; });
    try {
      if (isRegister) {
        await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: email.text.trim(),
          password: pass.text,
        );
      } else {
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: email.text.trim(),
          password: pass.text,
        );
      }
    } on FirebaseAuthException catch (e) {
      setState(() => err = e.message ?? e.code);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  void dispose() {
    email.dispose();
    pass.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(isRegister ? 'Create account' : 'Sign in')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: email,
              decoration: const InputDecoration(labelText: 'Email'),
              keyboardType: TextInputType.emailAddress,
            ),
            TextField(
              controller: pass,
              decoration: const InputDecoration(labelText: 'Password'),
              obscureText: true,
            ),
            const SizedBox(height: 12),
            if (err.isNotEmpty) Text(err, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: loading ? null : submit,
              child: Text(loading ? '...' : (isRegister ? 'Sign up' : 'Sign in')),
            ),
            TextButton(
              onPressed: () => setState(() => isRegister = !isRegister),
              child: Text(isRegister ? 'I already have an account' : 'Create an account'),
            )
          ],
        ),
      ),
    );
  }
}

class TodayTasksPage extends StatefulWidget {
  const TodayTasksPage({super.key});
  @override
  State<TodayTasksPage> createState() => _TodayTasksPageState();
}

class _TodayTasksPageState extends State<TodayTasksPage> {
  String todayKey() {
    final now = DateTime.now();
    final y = now.year.toString().padLeft(4, '0');
    final m = now.month.toString().padLeft(2, '0');
    final d = now.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  CollectionReference<Map<String, dynamic>> tasksRef() {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final day = todayKey();
    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('days')
        .doc(day)
        .collection('tasks');
  }

  Future<void> addTaskDialog() async {
    final controller = TextEditingController();
    final title = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('New task'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'e.g. Lecture notes + 10 flashcards'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(context, controller.text.trim()), child: const Text('Add')),
        ],
      ),
    );
    if (title == null || title.isEmpty) return;

    await tasksRef().add({
      'title': title,
      'done': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> toggleDone(String id, bool done) async {
    await tasksRef().doc(id).update({'done': !done});
  }

  Future<void> signOut() async => FirebaseAuth.instance.signOut();

  @override
  Widget build(BuildContext context) {
    final stream = tasksRef().orderBy('createdAt').snapshots();

    return Scaffold(
      appBar: AppBar(
        title: Text('Today • ${todayKey()}'),
        actions: [
          IconButton(onPressed: signOut, icon: const Icon(Icons.logout)),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: addTaskDialog,
        child: const Icon(Icons.add),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: stream,
        builder: (context, snap) {
          if (snap.hasError) return const Center(child: Text('Error loading tasks'));
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());

          final docs = snap.data!.docs;
          if (docs.isEmpty) return const Center(child: Text('No tasks yet. Tap +'));

          return ListView(
            children: docs.map((d) {
              final data = d.data();
              final title = (data['title'] ?? '').toString();
              final done = (data['done'] ?? false) as bool;
              return ListTile(
                title: Text(
                  title,
                  style: TextStyle(decoration: done ? TextDecoration.lineThrough : null),
                ),
                trailing: Checkbox(
                  value: done,
                  onChanged: (_) => toggleDone(d.id, done),
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }
}