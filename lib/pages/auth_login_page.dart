import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthLoginPage extends StatefulWidget {
  const AuthLoginPage({super.key});

  @override
  State<AuthLoginPage> createState() => _AuthLoginPageState();
}

class _AuthLoginPageState extends State<AuthLoginPage> {
  final email = TextEditingController();
  final pass = TextEditingController();
  bool register = false;
  String err = '';

  @override
  void dispose() {
    email.dispose();
    pass.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    setState(() => err = '');
    try {
      if (register) {
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
    } catch (e) {
      setState(() => err = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: scheme.surface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: scheme.outline.withValues(alpha: 0.35)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    "Study Grove",
                    style: TextStyle(
                      fontSize: 14,
                      letterSpacing: 1.2,
                      color: scheme.onSurface,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    register ? "Create account" : "Sign in",
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: email,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(labelText: "Email"),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: pass,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: "Password"),
                  ),
                  const SizedBox(height: 12),
                  if (err.isNotEmpty)
                    Text(err, style: const TextStyle(color: Colors.redAccent)),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: submit,
                      child: Text(register ? "Create account" : "Sign in"),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => setState(() => register = !register),
                    child: Text(
                      register
                          ? "I already have an account"
                          : "Create a new account",
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
