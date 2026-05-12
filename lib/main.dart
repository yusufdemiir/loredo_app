import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'firebase/auth_service.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key, this.home, this.authService});

  final Widget? home;
  final AuthService? authService;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Loredo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1F6F78)),
        scaffoldBackgroundColor: const Color(0xFFF5F7F8),
      ),
      home: home ?? AuthFlowScreen(authService: authService ?? AuthService()),
    );
  }
}

class AuthFlowScreen extends StatelessWidget {
  const AuthFlowScreen({super.key, required this.authService});

  final AuthService authService;

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
          return LoginScreen(authService: authService);
        }

        return HomeScreen(authService: authService, user: user);
      },
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.authService});

  final AuthService authService;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit(AuthAction action) async {
    if (_isSubmitting || !_formKey.currentState!.validate()) {
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() {
      _isSubmitting = true;
    });

    try {
      if (action == AuthAction.signIn) {
        await widget.authService.signInWithUsernameAndPassword(
          username: _usernameController.text,
          password: _passwordController.text,
        );
      } else {
        await widget.authService.registerWithUsernameAndPassword(
          username: _usernameController.text,
          password: _passwordController.text,
        );
      }
    } on AuthFailure catch (error) {
      if (!mounted) {
        return;
      }
      _showSnackBar(context, error.message, isError: true);
    } catch (_) {
      if (!mounted) {
        return;
      }
      _showSnackBar(
        context,
        'Beklenmeyen bir hata oluştu. Lütfen tekrar deneyin.',
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Loredo',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 24),
                      TextFormField(
                        controller: _usernameController,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'Kullanıcı adı',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          final username = value?.trim() ?? '';
                          if (username.isEmpty) {
                            return 'Kullanıcı adı zorunludur.';
                          }
                          if (username.length < 3) {
                            return 'Kullanıcı adı en az 3 karakter olmalıdır.';
                          }
                          if (!AuthService.isUsernameValid(username)) {
                            return 'Sadece harf, rakam, nokta ve alt çizgi kullanın.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: true,
                        onFieldSubmitted: (_) => _submit(AuthAction.signIn),
                        decoration: const InputDecoration(
                          labelText: 'Şifre',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if ((value ?? '').isEmpty) {
                            return 'Şifre zorunludur.';
                          }
                          if ((value ?? '').length < 6) {
                            return 'Şifre en az 6 karakter olmalıdır.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),
                      FilledButton(
                        onPressed: _isSubmitting
                            ? null
                            : () => _submit(AuthAction.signIn),
                        child: Text(
                          _isSubmitting ? 'İşleniyor...' : 'Giriş Yap',
                        ),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton(
                        onPressed: _isSubmitting
                            ? null
                            : () => _submit(AuthAction.register),
                        child: const Text('Kayıt Ol'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.authService, required this.user});

  final AuthService authService;
  final User user;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<UserProfile>(
      future: authService.fetchUserProfile(user.uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _LoadingScreen();
        }

        if (snapshot.hasError) {
          return Scaffold(
            appBar: AppBar(title: const Text('Loredo')),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Kullanıcı bilgileri yüklenemedi.'),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: authService.signOut,
                      child: const Text('Çıkış Yap'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        final profile = snapshot.data!;
        switch (profile.role) {
          case UserRoles.admin:
            return AdminHomeScreen(authService: authService, profile: profile);
          case UserRoles.sales:
            return SalesHomeScreen(authService: authService, profile: profile);
          case UserRoles.manufacturing:
            return ManufacturingHomeScreen(
              authService: authService,
              profile: profile,
            );
          case UserRoles.pending:
          default:
            return RoleMessageScreen(
              title: 'Loredo',
              message: 'Rolünüz onaylanıyor.',
              authService: authService,
            );
        }
      },
    );
  }
}

class SalesHomeScreen extends StatelessWidget {
  const SalesHomeScreen({
    super.key,
    required this.authService,
    required this.profile,
  });

  final AuthService authService;
  final UserProfile profile;

  @override
  Widget build(BuildContext context) {
    return _SalesLikeHomeScreen(
      title: 'Satışçı Paneli',
      authService: authService,
      profile: profile,
    );
  }
}

class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen({
    super.key,
    required this.authService,
    required this.profile,
  });

  final AuthService authService;
  final UserProfile profile;

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  String? _updatingUserId;

  Future<void> _updateRole({
    required AppUserSummary user,
    required String? nextRole,
  }) async {
    if (nextRole == null ||
        user.uid == widget.profile.uid ||
        user.role == nextRole ||
        _updatingUserId != null) {
      return;
    }

    setState(() {
      _updatingUserId = user.uid;
    });

    try {
      await widget.authService.updateUserRole(userId: user.uid, role: nextRole);
      if (!mounted) {
        return;
      }
      _showSnackBar(
        context,
        '${user.username} kullanıcısının rolü güncellendi.',
        isError: false,
      );
    } on AuthFailure catch (error) {
      if (!mounted) {
        return;
      }
      _showSnackBar(context, error.message, isError: true);
    } catch (_) {
      if (!mounted) {
        return;
      }
      _showSnackBar(
        context,
        'Rol güncellenemedi. Lütfen tekrar deneyin.',
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          _updatingUserId = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Yönetici Paneli'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Kullanıcılar'),
              Tab(text: 'Siparişler'),
              Tab(text: 'Müşteriler'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: widget.authService.signOut,
              child: const Text('Çıkış Yap'),
            ),
          ],
        ),
        body: TabBarView(
          children: [
            _AdminUsersTab(
              authService: widget.authService,
              currentProfile: widget.profile,
              updatingUserId: _updatingUserId,
              onRoleChanged: _updateRole,
            ),
            OrdersManagementTab(
              authService: widget.authService,
              profile: widget.profile,
            ),
            CustomersManagementTab(
              authService: widget.authService,
              profile: widget.profile,
            ),
          ],
        ),
      ),
    );
  }
}

class _AdminUsersTab extends StatelessWidget {
  const _AdminUsersTab({
    required this.authService,
    required this.currentProfile,
    required this.updatingUserId,
    required this.onRoleChanged,
  });

  final AuthService authService;
  final UserProfile currentProfile;
  final String? updatingUserId;
  final Future<void> Function({
    required AppUserSummary user,
    required String? nextRole,
  })
  onRoleChanged;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<AppUserSummary>>(
      stream: authService.watchAllUsers(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return const _CenteredPanel(
            child: Text(
              'Kullanıcı listesi yüklenemedi.',
              textAlign: TextAlign.center,
            ),
          );
        }

        final users = snapshot.data ?? const <AppUserSummary>[];
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    '${currentProfile.username} olarak yönetici girişi yaptınız.',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Kullanıcı rollerini buradan yönetebilirsiniz.',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 20),
                  Expanded(
                    child: users.isEmpty
                        ? const Card(
                            child: Center(
                              child: Padding(
                                padding: EdgeInsets.all(24),
                                child: Text('Henüz kayıtlı kullanıcı yok.'),
                              ),
                            ),
                          )
                        : Card(
                            child: ListView.separated(
                              padding: const EdgeInsets.all(16),
                              itemCount: users.length,
                              separatorBuilder: (_, _) =>
                                  const Divider(height: 24),
                              itemBuilder: (context, index) {
                                final listedUser = users[index];
                                final isCurrentUser =
                                    listedUser.uid == currentProfile.uid;
                                final isUpdating =
                                    listedUser.uid == updatingUserId;

                                return Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            listedUser.username,
                                            style: Theme.of(
                                              context,
                                            ).textTheme.titleMedium,
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            'Mevcut rol: ${_roleLabel(listedUser.role)}${isCurrentUser ? ' (siz)' : ''}',
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    SizedBox(
                                      width: 190,
                                      child: DropdownButtonFormField<String>(
                                        initialValue: listedUser.role,
                                        decoration: const InputDecoration(
                                          labelText: 'Rol',
                                          border: OutlineInputBorder(),
                                        ),
                                        onChanged: isCurrentUser || isUpdating
                                            ? null
                                            : (value) => onRoleChanged(
                                                user: listedUser,
                                                nextRole: value,
                                              ),
                                        items: _roleOptionsFor(listedUser.role)
                                            .map(
                                              (role) =>
                                                  DropdownMenuItem<String>(
                                                    value: role,
                                                    child: Text(
                                                      _roleLabel(role),
                                                    ),
                                                  ),
                                            )
                                            .toList(),
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SalesLikeHomeScreen extends StatelessWidget {
  const _SalesLikeHomeScreen({
    required this.title,
    required this.authService,
    required this.profile,
  });

  final String title;
  final AuthService authService;
  final UserProfile profile;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(title),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Siparişler'),
              Tab(text: 'Müşteriler'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: authService.signOut,
              child: const Text('Çıkış Yap'),
            ),
          ],
        ),
        body: TabBarView(
          children: [
            OrdersManagementTab(authService: authService, profile: profile),
            CustomersManagementTab(authService: authService, profile: profile),
          ],
        ),
      ),
    );
  }
}

class ManufacturingHomeScreen extends StatelessWidget {
  const ManufacturingHomeScreen({
    super.key,
    required this.authService,
    required this.profile,
  });

  final AuthService authService;
  final UserProfile profile;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('İmalatçı Paneli')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Siparişler',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            Expanded(
              child: OrdersListCard(
                authService: authService,
                profile: profile,
                canManageOrders: false,
              ),
            ),
            const SizedBox(height: 20),
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton(
                onPressed: authService.signOut,
                child: const Text('Çıkış Yap'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class OrdersManagementTab extends StatelessWidget {
  const OrdersManagementTab({
    super.key,
    required this.authService,
    required this.profile,
  });

  final AuthService authService;
  final UserProfile profile;

  Future<void> _openOrderForm(BuildContext context) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) =>
            OrderUpsertScreen(authService: authService, profile: profile),
      ),
    );
    if (changed == true && context.mounted) {
      _showSnackBar(context, 'Sipariş başarıyla kaydedildi.', isError: false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FilledButton(
            onPressed: () => _openOrderForm(context),
            child: const Text('Sipariş Oluştur'),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: OrdersListCard(
              authService: authService,
              profile: profile,
              canManageOrders: true,
            ),
          ),
        ],
      ),
    );
  }
}

class CustomersManagementTab extends StatelessWidget {
  const CustomersManagementTab({
    super.key,
    required this.authService,
    required this.profile,
  });

  final AuthService authService;
  final UserProfile profile;

  Future<void> _openCreateCustomer(BuildContext context) async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) =>
            CustomerCreateScreen(authService: authService, profile: profile),
      ),
    );
    if (created == true && context.mounted) {
      _showSnackBar(context, 'Müşteri eklendi.', isError: false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FilledButton(
            onPressed: () => _openCreateCustomer(context),
            child: const Text('Müşteri Ekle'),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Card(
              child: StreamBuilder<List<CustomerSummary>>(
                stream: authService.watchCustomers(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return const Center(
                      child: Text('Müşteri listesi yüklenemedi.'),
                    );
                  }
                  final customers = snapshot.data ?? const <CustomerSummary>[];
                  if (customers.isEmpty) {
                    return const Center(
                      child: Text('Henüz kayıtlı müşteri yok.'),
                    );
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: customers.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final customer = customers[index];
                      return ListTile(title: Text(customer.name));
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class OrdersListCard extends StatelessWidget {
  const OrdersListCard({
    super.key,
    required this.authService,
    required this.profile,
    required this.canManageOrders,
  });

  final AuthService authService;
  final UserProfile profile;
  final bool canManageOrders;

  void _openOrderDetail(BuildContext context, OrderSummary order) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => OrderDetailScreen(
          authService: authService,
          profile: profile,
          orderId: order.id,
          canManageOrders: canManageOrders,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: StreamBuilder<List<OrderSummary>>(
        stream: authService.watchAllOrders(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(child: Text('Sipariş listesi yüklenemedi.'));
          }
          final orders = snapshot.data ?? const <OrderSummary>[];
          if (orders.isEmpty) {
            return const Center(child: Text('Henüz oluşturulmuş sipariş yok.'));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: orders.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final order = orders[index];
              return ListTile(
                title: Text(order.customerName),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _openOrderDetail(context, order),
              );
            },
          );
        },
      ),
    );
  }
}

class CustomerCreateScreen extends StatefulWidget {
  const CustomerCreateScreen({
    super.key,
    required this.authService,
    required this.profile,
  });

  final AuthService authService;
  final UserProfile profile;

  @override
  State<CustomerCreateScreen> createState() => _CustomerCreateScreenState();
}

class _CustomerCreateScreenState extends State<CustomerCreateScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isSubmitting || !_formKey.currentState!.validate()) {
      return;
    }
    setState(() {
      _isSubmitting = true;
    });
    try {
      await widget.authService.createCustomer(
        createdBy: widget.profile,
        name: _nameController.text,
      );
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(true);
    } on AuthFailure catch (error) {
      if (!mounted) {
        return;
      }
      _showSnackBar(context, error.message, isError: true);
    } catch (_) {
      if (!mounted) {
        return;
      }
      _showSnackBar(context, 'Müşteri eklenemedi.', isError: true);
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Müşteri Ekle')),
      body: _CenteredPanel(
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Müşteri adı',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if ((value ?? '').trim().isEmpty) {
                        return 'Müşteri adı zorunludur.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: _isSubmitting ? null : _submit,
                    child: Text(
                      _isSubmitting ? 'Kaydediliyor...' : 'Müşteri Ekle',
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

class OrderUpsertScreen extends StatefulWidget {
  const OrderUpsertScreen({
    super.key,
    required this.authService,
    required this.profile,
    this.order,
  });

  final AuthService authService;
  final UserProfile profile;
  final OrderDetail? order;

  bool get isEditing => order != null;

  @override
  State<OrderUpsertScreen> createState() => _OrderUpsertScreenState();
}

class _OrderUpsertScreenState extends State<OrderUpsertScreen> {
  final _formKey = GlobalKey<FormState>();
  final _detailController = TextEditingController();
  final Map<String, TextEditingController> _quantityControllers =
      <String, TextEditingController>{};
  final Set<String> _selectedProductCodes = <String>{};

  String? _selectedCustomerId;
  DateTime? _selectedOrderDate;
  bool _isSubmitting = false;
  bool _showProductError = false;
  bool _showDateError = false;
  bool _showCustomerError = false;

  @override
  void initState() {
    super.initState();
    for (final option in AuthService.orderProductOptions) {
      _quantityControllers[option.code] = TextEditingController();
    }
    final order = widget.order;
    if (order != null) {
      _selectedCustomerId = order.customerId;
      _selectedOrderDate = order.orderDate;
      _detailController.text = order.orderDetail;
      for (final product in order.products) {
        _selectedProductCodes.add(product.productCode);
        _quantityControllers[product.productCode]?.text = product.quantity
            .toString();
      }
    }
  }

  @override
  void dispose() {
    _detailController.dispose();
    for (final controller in _quantityControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedOrderDate ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
    );
    if (pickedDate != null) {
      setState(() {
        _selectedOrderDate = pickedDate;
        _showDateError = false;
      });
    }
  }

  void _toggleProduct(bool? isSelected, String productCode) {
    setState(() {
      if (isSelected ?? false) {
        _selectedProductCodes.add(productCode);
        _showProductError = false;
      } else {
        _selectedProductCodes.remove(productCode);
        _quantityControllers[productCode]?.clear();
      }
    });
  }

  Future<void> _submit() async {
    final isFormValid = _formKey.currentState!.validate();
    final hasProducts = _selectedProductCodes.isNotEmpty;
    final hasDate = _selectedOrderDate != null;
    final hasCustomer = (_selectedCustomerId ?? '').isNotEmpty;

    setState(() {
      _showProductError = !hasProducts;
      _showDateError = !hasDate;
      _showCustomerError = !hasCustomer;
    });

    if (!isFormValid ||
        !hasProducts ||
        !hasDate ||
        !hasCustomer ||
        _isSubmitting) {
      return;
    }

    final products = AuthService.orderProductOptions
        .where((option) => _selectedProductCodes.contains(option.code))
        .map(
          (option) => OrderLineItemInput(
            productCode: option.code,
            productName: option.name,
            quantity: int.parse(_quantityControllers[option.code]!.text.trim()),
          ),
        )
        .toList();

    setState(() {
      _isSubmitting = true;
    });

    try {
      if (widget.isEditing) {
        await widget.authService.updateOrder(
          updatedBy: widget.profile,
          orderId: widget.order!.id,
          customerId: _selectedCustomerId!,
          products: products,
          orderDate: _selectedOrderDate!,
          orderDetail: _detailController.text,
        );
      } else {
        await widget.authService.createOrder(
          createdBy: widget.profile,
          customerId: _selectedCustomerId!,
          products: products,
          orderDate: _selectedOrderDate!,
          orderDetail: _detailController.text,
        );
      }
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(true);
    } on AuthFailure catch (error) {
      if (!mounted) {
        return;
      }
      _showSnackBar(context, error.message, isError: true);
    } catch (_) {
      if (!mounted) {
        return;
      }
      _showSnackBar(context, 'Sipariş kaydedilemedi.', isError: true);
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEditing ? 'Siparişi Düzenle' : 'Sipariş Oluştur'),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      StreamBuilder<List<CustomerSummary>>(
                        stream: widget.authService.watchCustomers(),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const Center(
                              child: CircularProgressIndicator(),
                            );
                          }
                          if (snapshot.hasError) {
                            return const Text('Müşteri listesi yüklenemedi.');
                          }
                          final customers =
                              snapshot.data ?? const <CustomerSummary>[];
                          return DropdownButtonFormField<String>(
                            initialValue:
                                customers.any(
                                  (customer) =>
                                      customer.id == _selectedCustomerId,
                                )
                                ? _selectedCustomerId
                                : null,
                            decoration: const InputDecoration(
                              labelText: 'Müşteri',
                              border: OutlineInputBorder(),
                            ),
                            items: customers
                                .map(
                                  (customer) => DropdownMenuItem<String>(
                                    value: customer.id,
                                    child: Text(customer.name),
                                  ),
                                )
                                .toList(),
                            onChanged: (value) {
                              setState(() {
                                _selectedCustomerId = value;
                                _showCustomerError = false;
                              });
                            },
                          );
                        },
                      ),
                      if (_showCustomerError)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            'Müşteri seçimi zorunludur.',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ),
                      const SizedBox(height: 20),
                      Text(
                        'Sipariş edilen ürünler',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      for (final option in AuthService.orderProductOptions) ...[
                        _ProductSelectionRow(
                          option: option,
                          isSelected: _selectedProductCodes.contains(
                            option.code,
                          ),
                          controller: _quantityControllers[option.code]!,
                          onChanged: (value) =>
                              _toggleProduct(value, option.code),
                        ),
                        const SizedBox(height: 12),
                      ],
                      if (_showProductError)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Text(
                            'En az bir ürün seçmelisiniz.',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: _pickDate,
                        icon: const Icon(Icons.calendar_today),
                        label: Text(
                          _selectedOrderDate == null
                              ? 'Sipariş tarihi seç'
                              : 'Sipariş tarihi: ${_formatDate(_selectedOrderDate!)}',
                        ),
                      ),
                      if (_showDateError)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            'Sipariş tarihi zorunludur.',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ),
                      const SizedBox(height: 20),
                      TextFormField(
                        controller: _detailController,
                        minLines: 4,
                        maxLines: 8,
                        decoration: const InputDecoration(
                          labelText: 'Sipariş detayı',
                          alignLabelWithHint: true,
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 24),
                      FilledButton(
                        onPressed: _isSubmitting ? null : _submit,
                        child: Text(
                          _isSubmitting
                              ? 'Kaydediliyor...'
                              : widget.isEditing
                              ? 'Siparişi Güncelle'
                              : 'Siparişi Oluştur',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ProductSelectionRow extends StatelessWidget {
  const _ProductSelectionRow({
    required this.option,
    required this.isSelected,
    required this.controller,
    required this.onChanged,
  });

  final OrderProductOption option;
  final bool isSelected;
  final TextEditingController controller;
  final ValueChanged<bool?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 3,
          child: CheckboxListTile(
            value: isSelected,
            onChanged: onChanged,
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
            title: Text(option.name),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: TextFormField(
            controller: controller,
            enabled: isSelected,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Adet',
              border: OutlineInputBorder(),
            ),
            validator: (value) {
              if (!isSelected) {
                return null;
              }
              final quantity = int.tryParse((value ?? '').trim());
              if (quantity == null || quantity <= 0) {
                return 'Geçerli adet girin.';
              }
              return null;
            },
          ),
        ),
      ],
    );
  }
}

class OrderDetailScreen extends StatefulWidget {
  const OrderDetailScreen({
    super.key,
    required this.authService,
    required this.profile,
    required this.orderId,
    required this.canManageOrders,
  });

  final AuthService authService;
  final UserProfile profile;
  final String orderId;
  final bool canManageOrders;

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  late Future<OrderDetail> _orderFuture;

  @override
  void initState() {
    super.initState();
    _orderFuture = widget.authService.fetchOrder(widget.orderId);
  }

  Future<void> _reload() async {
    setState(() {
      _orderFuture = widget.authService.fetchOrder(widget.orderId);
    });
  }

  Future<void> _edit(OrderDetail order) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => OrderUpsertScreen(
          authService: widget.authService,
          profile: widget.profile,
          order: order,
        ),
      ),
    );
    if (changed == true && mounted) {
      await _reload();
      if (mounted) {
        _showSnackBar(context, 'Sipariş güncellendi.', isError: false);
      }
    }
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Siparişi sil'),
        content: const Text('Bu siparişi silmek istediğinizden emin misiniz?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Sil'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) {
      return;
    }

    try {
      await widget.authService.deleteOrder(
        deletedBy: widget.profile,
        orderId: widget.orderId,
      );
      if (!mounted) {
        return;
      }
      _showSnackBar(context, 'Sipariş silindi.', isError: false);
      Navigator.of(context).pop(true);
    } on AuthFailure catch (error) {
      if (!mounted) {
        return;
      }
      _showSnackBar(context, error.message, isError: true);
    } catch (_) {
      if (!mounted) {
        return;
      }
      _showSnackBar(context, 'Sipariş silinemedi.', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sipariş Detayı'),
        actions: widget.canManageOrders
            ? [
                IconButton(
                  onPressed: () async {
                    final order = await _orderFuture;
                    if (mounted) {
                      await _edit(order);
                    }
                  },
                  icon: const Icon(Icons.edit),
                ),
                IconButton(onPressed: _delete, icon: const Icon(Icons.delete)),
              ]
            : null,
      ),
      body: FutureBuilder<OrderDetail>(
        future: _orderFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const _LoadingScreen();
          }
          if (snapshot.hasError) {
            return const _CenteredPanel(
              child: Text(
                'Sipariş bilgileri yüklenemedi.',
                textAlign: TextAlign.center,
              ),
            );
          }
          final order = snapshot.data!;
          return Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _DetailItem(
                          label: 'Müşteri',
                          value: order.customerName,
                        ),
                        const SizedBox(height: 16),
                        _DetailItem(
                          label: 'Sipariş tarihi',
                          value: order.orderDate == null
                              ? 'Belirtilmemiş'
                              : _formatDate(order.orderDate!),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Ürünler',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        for (final product in order.products)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Text(
                              '${product.productName} - ${product.quantity} adet',
                            ),
                          ),
                        const SizedBox(height: 16),
                        _DetailItem(
                          label: 'Sipariş detayı',
                          value: order.orderDetail.isEmpty
                              ? 'Detay girilmemiş.'
                              : order.orderDetail,
                        ),
                        const SizedBox(height: 16),
                        _DetailItem(
                          label: 'Oluşturan kullanıcı',
                          value: order.createdByUsername,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _DetailItem extends StatelessWidget {
  const _DetailItem({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Text(value),
      ],
    );
  }
}

class RoleMessageScreen extends StatelessWidget {
  const RoleMessageScreen({
    super.key,
    required this.title,
    required this.message,
    required this.authService,
  });

  final String title;
  final String message;
  final AuthService authService;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: _CenteredPanel(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: authService.signOut,
              child: const Text('Çıkış Yap'),
            ),
          ],
        ),
      ),
    );
  }
}

class _CenteredPanel extends StatelessWidget {
  const _CenteredPanel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: child,
        ),
      ),
    );
  }
}

class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}

String _roleLabel(String role) {
  switch (role) {
    case UserRoles.admin:
      return 'Admin';
    case UserRoles.sales:
      return 'Satışçı';
    case UserRoles.manufacturing:
      return 'İmalatçı';
    case UserRoles.pending:
    default:
      return 'Beklemede';
  }
}

List<String> _roleOptionsFor(String currentRole) {
  final roles = <String>[
    if (!AuthService.assignableRoles.contains(currentRole)) currentRole,
    ...AuthService.assignableRoles,
  ];
  return roles.toSet().toList();
}

String _formatDate(DateTime date) {
  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');
  final year = date.year.toString();
  return '$day.$month.$year';
}

void _showSnackBar(
  BuildContext context,
  String message, {
  required bool isError,
}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red.shade700 : Colors.green.shade700,
      ),
    );
}

enum AuthAction { signIn, register }
