import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:client/providers/likedArticleProvider.dart';
import 'package:client/screens/RegisterScreen.dart';
import 'package:client/services/api_client.dart';
import 'package:client/widgets/applogo.dart';
import 'package:client/widgets/theme.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final email = _email.text.trim();
      final token = await Api.login(email, _password.text);
      if (!mounted) return;
      await context.read<LikedArticlesProvider>().startSession(email, token);
      if (mounted) Navigator.of(context).pushNamedAndRemoveUntil('home/', (_) => false);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: 'Welcome back',
      subtitle: 'Sign in to see your personalized news.',
      children: [
        Form(
          key: _formKey,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.email],
              decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.mail_outline_rounded)),
              validator: (v) => (v == null || !v.contains('@')) ? 'Enter a valid email address' : null,
            ),
            const SizedBox(height: Space.md),
            TextFormField(
              controller: _password,
              obscureText: _obscure,
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.password],
              onFieldSubmitted: (_) => _submit(),
              decoration: InputDecoration(
                labelText: 'Password',
                prefixIcon: const Icon(Icons.lock_outline_rounded),
                suffixIcon: IconButton(
                  tooltip: _obscure ? 'Show password' : 'Hide password',
                  icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
              validator: (v) => (v == null || v.isEmpty) ? 'Enter your password' : null,
            ),
          ]),
        ),
        if (_error != null) ...[
          const SizedBox(height: Space.md),
          _ErrorBanner(_error!),
        ],
        const SizedBox(height: Space.lg),
        LoadingButton(loading: _loading, label: 'Sign in', onPressed: _submit),
        const SizedBox(height: Space.md),
        Wrap(alignment: WrapAlignment.center, crossAxisAlignment: WrapCrossAlignment.center, children: [
          Text("Don't have an account?", style: context.text.bodyMedium),
          TextButton(
            onPressed: () async {
              final email = await Navigator.push<String>(
                context, MaterialPageRoute(builder: (_) => const MyRegisterPage()),
              );
              if (email != null && mounted) {
                _email.text = email;
                showMessage(this.context, 'Account created. Sign in to continue.');
              }
            },
            child: const Text('Create one'),
          ),
        ]),
      ],
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner(this.message);

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(Space.md),
        decoration: BoxDecoration(
          color: context.colors.error.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(children: [
          Icon(Icons.error_outline_rounded, color: context.colors.error),
          const SizedBox(width: Space.sm),
          Expanded(child: Text(message, style: TextStyle(color: context.colors.error))),
        ]),
      ),
    );
  }
}
