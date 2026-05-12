import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  AuthService({FirebaseAuth? auth, FirebaseFirestore? firestore})
    : _auth = auth ?? FirebaseAuth.instance,
      _firestore = firestore ?? FirebaseFirestore.instance;

  static final RegExp _usernamePattern = RegExp(r'^[a-zA-Z0-9._]+$');
  static const List<String> assignableRoles = <String>[
    UserRoles.pending,
    UserRoles.sales,
    UserRoles.manufacturing,
  ];
  static const List<OrderProductOption> orderProductOptions =
      <OrderProductOption>[
        OrderProductOption(code: 'cheesecake', name: 'Cheesecake'),
        OrderProductOption(code: 'profiterol', name: 'Profiterol'),
      ];

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  Stream<User?> authStateChanges() => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  static bool isUsernameValid(String username) {
    return _usernamePattern.hasMatch(username.trim());
  }

  Future<UserCredential> signInWithUsernameAndPassword({
    required String username,
    required String password,
  }) async {
    final normalizedUsername = _normalizeUsername(username);

    try {
      return await _auth.signInWithEmailAndPassword(
        email: _emailFromUsername(normalizedUsername),
        password: password,
      );
    } on FirebaseAuthException catch (error) {
      throw AuthFailure(_mapAuthError(error));
    }
  }

  Future<UserCredential> registerWithUsernameAndPassword({
    required String username,
    required String password,
  }) async {
    final normalizedUsername = _normalizeUsername(username);

    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: _emailFromUsername(normalizedUsername),
        password: password,
      );

      final user = credential.user;
      if (user == null) {
        throw const AuthFailure('Kullanıcı oluşturulamadı.');
      }

      await _firestore.collection('users').doc(user.uid).set({
        'username': normalizedUsername,
        'role': UserRoles.pending,
        'permissions': <String>[],
        'createdAt': FieldValue.serverTimestamp(),
      });

      return credential;
    } on FirebaseAuthException catch (error) {
      throw AuthFailure(_mapAuthError(error));
    } on FirebaseException catch (_) {
      await _auth.currentUser?.delete();
      throw const AuthFailure(
        'Kullanıcı kaydı oluşturuldu ancak profil kaydedilemedi.',
      );
    }
  }

  Future<UserProfile> fetchUserProfile(String userId) async {
    final snapshot = await _firestore.collection('users').doc(userId).get();
    final data = snapshot.data();

    if (data == null) {
      throw const AuthFailure('Kullanıcı profili bulunamadı.');
    }

    return UserProfile(
      uid: userId,
      username: (data['username'] as String?) ?? 'Bilinmeyen kullanıcı',
      role: _normalizeRole(data['role'] as String?),
      permissions: List<String>.from(data['permissions'] as List? ?? const []),
    );
  }

  Stream<List<AppUserSummary>> watchAllUsers() {
    return _firestore
        .collection('users')
        .orderBy('username')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(
                (doc) => AppUserSummary(
                  uid: doc.id,
                  username:
                      (doc.data()['username'] as String?) ??
                      'Bilinmeyen kullanıcı',
                  role: _normalizeRole(doc.data()['role'] as String?),
                ),
              )
              .toList(),
        );
  }

  Future<void> updateUserRole({
    required String userId,
    required String role,
  }) async {
    if (!assignableRoles.contains(role)) {
      throw const AuthFailure('Geçersiz rol seçildi.');
    }

    await _firestore.collection('users').doc(userId).update({'role': role});
  }

  Stream<List<CustomerSummary>> watchCustomers() {
    return _firestore
        .collection('musteriler')
        .orderBy('ad')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(
                (doc) => CustomerSummary(
                  id: doc.id,
                  name: (doc.data()['ad'] as String?) ?? 'Bilinmeyen müşteri',
                ),
              )
              .toList(),
        );
  }

  Future<void> createCustomer({
    required UserProfile createdBy,
    required String name,
  }) async {
    _ensureCanManageCustomers(createdBy.role);

    final normalizedName = name.trim();
    if (normalizedName.isEmpty) {
      throw const AuthFailure('Müşteri adı zorunludur.');
    }

    await _firestore.collection('musteriler').add({
      'ad': normalizedName,
      'olusturanUserId': createdBy.uid,
      'olusturanUsername': createdBy.username,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> createOrder({
    required UserProfile createdBy,
    required String customerId,
    required List<OrderLineItemInput> products,
    required DateTime orderDate,
    required String orderDetail,
  }) async {
    _ensureCanManageOrders(createdBy.role);

    final customer = await _fetchCustomer(customerId);
    final selectedProducts = _validateProducts(products);

    await _firestore.collection('siparisler').add({
      'musteriId': customer.id,
      'urunler': selectedProducts,
      'siparisTarihi': Timestamp.fromDate(
        DateTime(orderDate.year, orderDate.month, orderDate.day),
      ),
      'siparisDetayi': orderDetail.trim(),
      'olusturanUserId': createdBy.uid,
      'olusturanUsername': createdBy.username,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateOrder({
    required UserProfile updatedBy,
    required String orderId,
    required String customerId,
    required List<OrderLineItemInput> products,
    required DateTime orderDate,
    required String orderDetail,
  }) async {
    _ensureCanManageOrders(updatedBy.role);

    final customer = await _fetchCustomer(customerId);
    final selectedProducts = _validateProducts(products);

    await _firestore.collection('siparisler').doc(orderId).update({
      'musteriId': customer.id,
      'urunler': selectedProducts,
      'siparisTarihi': Timestamp.fromDate(
        DateTime(orderDate.year, orderDate.month, orderDate.day),
      ),
      'siparisDetayi': orderDetail.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteOrder({
    required UserProfile deletedBy,
    required String orderId,
  }) async {
    _ensureCanManageOrders(deletedBy.role);
    await _firestore.collection('siparisler').doc(orderId).delete();
  }

  Stream<List<OrderSummary>> watchAllOrders() {
    return _firestore
        .collection('siparisler')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .asyncMap((snapshot) async {
          final orders = <OrderSummary>[];
          for (final doc in snapshot.docs) {
            final data = doc.data();
            final customerId = (data['musteriId'] as String?) ?? '';
            final customerName = await _resolveCustomerName(customerId);
            orders.add(
              OrderSummary(
                id: doc.id,
                customerId: customerId,
                customerName: customerName,
              ),
            );
          }
          return orders;
        });
  }

  Future<OrderDetail> fetchOrder(String orderId) async {
    final snapshot = await _firestore
        .collection('siparisler')
        .doc(orderId)
        .get();
    final data = snapshot.data();

    if (data == null) {
      throw const AuthFailure('Sipariş bulunamadı.');
    }

    final rawProducts = (data['urunler'] as List?) ?? const [];
    final customerId = (data['musteriId'] as String?) ?? '';
    final customerName = await _resolveCustomerName(customerId);

    return OrderDetail(
      id: snapshot.id,
      customerId: customerId,
      customerName: customerName,
      products: rawProducts
          .whereType<Map>()
          .map(
            (item) => OrderLineItem(
              productCode: (item['urunKodu'] as String?) ?? '',
              productName: (item['urunAdi'] as String?) ?? 'Bilinmeyen ürün',
              quantity: (item['adet'] as num?)?.toInt() ?? 0,
            ),
          )
          .toList(),
      orderDate: (data['siparisTarihi'] as Timestamp?)?.toDate(),
      orderDetail: (data['siparisDetayi'] as String?) ?? '',
      createdByUserId: (data['olusturanUserId'] as String?) ?? '',
      createdByUsername: (data['olusturanUsername'] as String?) ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  Future<void> signOut() => _auth.signOut();

  void _ensureCanManageOrders(String role) {
    if (role != UserRoles.sales && role != UserRoles.admin) {
      throw const AuthFailure(
        'Bu işlem için satışçı veya admin yetkisi gerekir.',
      );
    }
  }

  void _ensureCanManageCustomers(String role) {
    if (role != UserRoles.sales && role != UserRoles.admin) {
      throw const AuthFailure(
        'Bu işlem için satışçı veya admin yetkisi gerekir.',
      );
    }
  }

  Future<CustomerSummary> _fetchCustomer(String customerId) async {
    if (customerId.trim().isEmpty) {
      throw const AuthFailure('Müşteri seçimi zorunludur.');
    }

    final snapshot = await _firestore
        .collection('musteriler')
        .doc(customerId)
        .get();
    final data = snapshot.data();
    if (data == null) {
      throw const AuthFailure('Seçilen müşteri bulunamadı.');
    }

    return CustomerSummary(
      id: snapshot.id,
      name: (data['ad'] as String?) ?? 'Bilinmeyen müşteri',
    );
  }

  Future<String> _resolveCustomerName(String customerId) async {
    if (customerId.isEmpty) {
      return 'Bilinmeyen müşteri';
    }

    final snapshot = await _firestore
        .collection('musteriler')
        .doc(customerId)
        .get();
    return (snapshot.data()?['ad'] as String?) ?? 'Bilinmeyen müşteri';
  }

  List<Map<String, Object>> _validateProducts(
    List<OrderLineItemInput> products,
  ) {
    if (products.isEmpty) {
      throw const AuthFailure('En az bir ürün seçmelisiniz.');
    }

    return products.map((product) {
      if (!orderProductOptions.any(
        (option) => option.code == product.productCode,
      )) {
        throw const AuthFailure('Geçersiz ürün seçildi.');
      }
      if (product.quantity <= 0) {
        throw const AuthFailure('Ürün adedi 1 veya daha büyük olmalıdır.');
      }

      return <String, Object>{
        'urunKodu': product.productCode,
        'urunAdi': product.productName,
        'adet': product.quantity,
      };
    }).toList();
  }

  String _normalizeUsername(String username) {
    final trimmed = username.trim().toLowerCase();

    if (trimmed.length < 3 || !isUsernameValid(trimmed)) {
      throw const AuthFailure(
        'Kullanıcı adı en az 3 karakter olmalı ve yalnızca harf, rakam, nokta veya alt çizgi içermelidir.',
      );
    }

    return trimmed;
  }

  String _normalizeRole(String? role) {
    switch (role) {
      case UserRoles.admin:
      case UserRoles.sales:
      case UserRoles.manufacturing:
      case UserRoles.pending:
        return role!;
      case 'kullanici':
      case null:
      case '':
        return UserRoles.pending;
      default:
        return UserRoles.pending;
    }
  }

  static String _emailFromUsername(String username) =>
      '$username@loredoapp.example.com';

  String _mapAuthError(FirebaseAuthException error) {
    final message = error.message?.toLowerCase() ?? '';

    if (message.contains('keychain') || message.contains('entitlement')) {
      return 'macOS kimlik doğrulama yapılandırması eksik. Uygulamayı temizleyip yeniden derleyin ve imzalama ayarlarını kontrol edin.';
    }

    switch (error.code) {
      case 'invalid-credential':
      case 'wrong-password':
      case 'user-not-found':
        return 'Kullanıcı adı veya şifre hatalı.';
      case 'email-already-in-use':
        return 'Bu kullanıcı adı zaten kayıtlı.';
      case 'invalid-email':
        return 'Kullanıcı adı için oluşturulan e-posta adresi geçersiz.';
      case 'weak-password':
        return 'Şifre çok zayıf. Daha güçlü bir şifre girin.';
      case 'too-many-requests':
        return 'Çok fazla deneme yapıldı. Lütfen daha sonra tekrar deneyin.';
      case 'network-request-failed':
        return 'Ağ bağlantısı kurulamadı. İnternet erişimini kontrol edin.';
      case 'internal-error':
      case 'unknown':
        if (message.contains('keychain') || message.contains('entitlement')) {
          return 'macOS kimlik doğrulama yapılandırması eksik. Uygulamayı temizleyip yeniden derleyin ve imzalama ayarlarını kontrol edin.';
        }
        return error.message ?? 'Kimlik doğrulama işlemi başarısız oldu.';
      default:
        return error.message ?? 'Kimlik doğrulama işlemi başarısız oldu.';
    }
  }
}

class UserProfile {
  const UserProfile({
    required this.uid,
    required this.username,
    required this.role,
    required this.permissions,
  });

  final String uid;
  final String username;
  final String role;
  final List<String> permissions;
}

class AppUserSummary {
  const AppUserSummary({
    required this.uid,
    required this.username,
    required this.role,
  });

  final String uid;
  final String username;
  final String role;
}

class CustomerSummary {
  const CustomerSummary({required this.id, required this.name});

  final String id;
  final String name;
}

class OrderProductOption {
  const OrderProductOption({required this.code, required this.name});

  final String code;
  final String name;
}

class OrderLineItemInput {
  const OrderLineItemInput({
    required this.productCode,
    required this.productName,
    required this.quantity,
  });

  final String productCode;
  final String productName;
  final int quantity;
}

class OrderLineItem {
  const OrderLineItem({
    required this.productCode,
    required this.productName,
    required this.quantity,
  });

  final String productCode;
  final String productName;
  final int quantity;
}

class OrderSummary {
  const OrderSummary({
    required this.id,
    required this.customerId,
    required this.customerName,
  });

  final String id;
  final String customerId;
  final String customerName;
}

class OrderDetail {
  const OrderDetail({
    required this.id,
    required this.customerId,
    required this.customerName,
    required this.products,
    required this.orderDate,
    required this.orderDetail,
    required this.createdByUserId,
    required this.createdByUsername,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String customerId;
  final String customerName;
  final List<OrderLineItem> products;
  final DateTime? orderDate;
  final String orderDetail;
  final String createdByUserId;
  final String createdByUsername;
  final DateTime? createdAt;
  final DateTime? updatedAt;
}

abstract final class UserRoles {
  static const String admin = 'admin';
  static const String sales = 'satisci';
  static const String manufacturing = 'imalatci';
  static const String pending = 'beklemede';
}

class AuthFailure implements Exception {
  const AuthFailure(this.message);

  final String message;

  @override
  String toString() => message;
}
