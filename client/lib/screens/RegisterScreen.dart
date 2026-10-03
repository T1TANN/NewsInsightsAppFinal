import 'package:flutter/material.dart';
import 'package:client/services/api_client.dart';
import 'package:client/widgets/applogo.dart';
import 'package:client/widgets/theme.dart';

class MyRegisterPage extends StatefulWidget {
  const MyRegisterPage({super.key});

  @override
  State<MyRegisterPage> createState() => _RegistrationState();
}

class _RegistrationState extends State<MyRegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _username = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    for (final c in [_username, _phone, _email, _password]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await Api.register(
        email: _email.text.trim(),
        password: _password.text,
        username: _username.text.trim(),
        phone: _phone.text.trim(),
      );
      // Back to sign-in with the email filled in.
      if (mounted) Navigator.pop(context, _email.text.trim());
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      showBack: true,
      title: 'Create account',
      subtitle: 'Like stories to build your personal feed.',
      children: [
        Form(
          key: _formKey,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            TextFormField(
              controller: _username,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.username],
              decoration: const InputDecoration(labelText: 'Username', prefixIcon: Icon(Icons.person_outline_rounded)),
              validator: (v) => (v == null || v.trim().length < 3) ? 'Use at least 3 characters' : null,
            ),
            const SizedBox(height: Space.md),
            TextFormField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.telephoneNumber],
              decoration: const InputDecoration(labelText: 'Phone number', prefixIcon: Icon(Icons.phone_outlined)),
              validator: (v) => (v == null || v.replaceAll(RegExp(r'\D'), '').length < 7)
                  ? 'Enter a valid phone number'
                  : null,
            ),
            const SizedBox(height: Space.md),
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.email],
              decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.mail_outline_rounded)),
              validator: (v) => (v == null || !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v.trim()))
                  ? 'Enter a valid email address'
                  : null,
            ),
            const SizedBox(height: Space.md),
            TextFormField(
              controller: _password,
              obscureText: _obscure,
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.newPassword],
              onFieldSubmitted: (_) => _submit(),
              decoration: InputDecoration(
                labelText: 'Password',
                helperText: 'At least 6 characters',
                prefixIcon: const Icon(Icons.lock_outline_rounded),
                suffixIcon: IconButton(
                  tooltip: _obscure ? 'Show password' : 'Hide password',
                  icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
              validator: (v) => (v == null || v.length < 6) ? 'Use at least 6 characters' : null,
            ),
          ]),
        ),
        if (_error != null) ...[
          const SizedBox(height: Space.md),
          Text(_error!, style: TextStyle(color: context.colors.error)),
        ],
        const SizedBox(height: Space.lg),
        LoadingButton(loading: _loading, label: 'Create account', onPressed: _submit),
        const SizedBox(height: Space.md),
        Wrap(alignment: WrapAlignment.center, crossAxisAlignment: WrapCrossAlignment.center, children: [
          Text('Already have an account?', style: context.text.bodyMedium),
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Sign in')),
        ]),
      ],
    );
  }
}
