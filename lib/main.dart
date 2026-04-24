import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';

import 'firebase/auth_service.dart';
import 'firebase/journal_repository.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({
    super.key,
    this.home,
    this.authService,
    this.journalRepository,
  });

  final Widget? home;
  final AuthService? authService;
  final JournalRepository? journalRepository;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Loredo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home:
          home ??
          FirebaseHomePage(
            authService: authService ?? AuthService(),
            journalRepository: journalRepository ?? JournalRepository(),
          ),
    );
  }
}

class FirebaseHomePage extends StatelessWidget {
  const FirebaseHomePage({
    super.key,
    required this.authService,
    required this.journalRepository,
  });

  final AuthService authService;
  final JournalRepository journalRepository;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: authService.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _LoadingScreen();
        }

        final user = snapshot.data;
        if (user == null) {
          return _SignInScreen(authService: authService);
        }

        return JournalScreen(
          authService: authService,
          journalRepository: journalRepository,
          user: user,
        );
      },
    );
  }
}

class JournalScreen extends StatefulWidget {
  const JournalScreen({
    super.key,
    required this.authService,
    required this.journalRepository,
    required this.user,
  });

  final AuthService authService;
  final JournalRepository journalRepository;
  final User user;

  @override
  State<JournalScreen> createState() => _JournalScreenState();
}

class _JournalScreenState extends State<JournalScreen> {
  final TextEditingController _controller = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _addEntry() async {
    setState(() {
      _submitting = true;
    });

    try {
      await widget.journalRepository.addEntry(
        userId: widget.user.uid,
        text: _controller.text,
      );
      _controller.clear();
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('Loredo Firebase Demo'),
        actions: [
          IconButton(
            onPressed: widget.authService.signOut,
            tooltip: 'Sign out',
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'User: ${widget.user.uid}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _controller,
              decoration: const InputDecoration(
                labelText: 'Journal entry',
                border: OutlineInputBorder(),
              ),
              minLines: 1,
              maxLines: 3,
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _submitting ? null : _addEntry,
              icon: const Icon(Icons.add),
              label: Text(_submitting ? 'Saving...' : 'Add entry'),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: widget.journalRepository.watchEntries(widget.user.uid),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Text('Firestore error: ${snapshot.error}');
                  }

                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final docs = snapshot.data?.docs ?? [];
                  if (docs.isEmpty) {
                    return const Center(
                      child: Text('No entries yet. Add your first record.'),
                    );
                  }

                  return ListView.separated(
                    itemCount: docs.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final data = docs[index].data();
                      final createdAt = data['createdAt'];
                      final timestamp = createdAt is Timestamp
                          ? createdAt.toDate().toLocal().toString()
                          : 'Pending server timestamp';

                      return Card(
                        child: ListTile(
                          title: Text((data['text'] as String?) ?? ''),
                          subtitle: Text(timestamp),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SignInScreen extends StatefulWidget {
  const _SignInScreen({required this.authService});

  final AuthService authService;

  @override
  State<_SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<_SignInScreen> {
  bool _loading = false;
  String? _error;

  Future<void> _signIn() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await widget.authService.signInAnonymously();
    } on FirebaseAuthException catch (error) {
      setState(() {
        _error = error.message ?? error.code;
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Loredo Firebase Demo')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Firebase Auth and Cloud Firestore are connected.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _loading ? null : _signIn,
                child: Text(_loading ? 'Signing in...' : 'Continue anonymously'),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
