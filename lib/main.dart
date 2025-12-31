import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'Livres/livre.dart';
import 'Emprunts/emprunt.dart';
import 'Profile/profile.dart';
import 'Reservations/resservation.dart';
import 'Login/login.dart';
void main() {
  runApp(const MyApp());
}



class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Gestion Bibliothèque',
      theme: ThemeData(primarySwatch: Colors.blue, useMaterial3: true),
      debugShowCheckedModeBanner: false,
      home: const LoginScreen(),
    );
  }
}
class HomeScreen extends StatefulWidget {
  final String userName;
  final String userEmail;
  final String fullName;
  
  final int userId;

  const HomeScreen({
    super.key,
    required this.userName,
  required this.userEmail,
  required this.fullName,
   required this.userId,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // === API CONFIGURATION ===
  final String loansApiUrl = 'https://libratech-backend.onrender.com/api/loans/';
  final String booksApiUrl = 'https://libratech-backend.onrender.com/api/books/';

  // === DONNÉES ===
  int _selectedIndex = 0;
  bool isLoading = true;
  String? errorMessage;
  late String displayName; 
  late String userEmail;
  late int userId;
  List<Map<String, dynamic>> currentLoans = [];
  List<Map<String, dynamic>> suggestions = [];

  int totalBorrows = 0;
  int toReturnSoon = 0;
  int reservations = 0;
  int overdueBooks = 0;

  @override
  void initState() {
    super.initState();
    displayName = widget.fullName;
    userEmail = widget.userEmail;
    userId = widget.userId;
    _fetchHomeData();
  }

  // === API CALLS ===

  /// Récupérer les données pour l'écran d'accueil
 Future<void> _fetchHomeData() async {
  setState(() {
    isLoading = true;
    errorMessage = null;
  });

  try {
    final loansResponse = await http.get(Uri.parse(loansApiUrl));
    final booksResponse = await http.get(Uri.parse(booksApiUrl));

    if (loansResponse.statusCode == 200 && booksResponse.statusCode == 200) {
      final loansData = jsonDecode(loansResponse.body);
      final booksData = jsonDecode(booksResponse.body);

      print('🔍 LOANS API RESPONSE:');
      print(loansData);
      print('---');

      List<dynamic> loansArray =
          loansData is List ? loansData : loansData['results'] ?? [];
      List<dynamic> booksArray =
          booksData is List ? booksData : booksData['results'] ?? [];

      setState(() {
        currentLoans = [];
        totalBorrows = loansArray.length;
        overdueBooks = 0;

        for (var loan in loansArray) {
          print('📌 Processing loan: $loan');
          
          bool isReturned = loan['status'] == 'returned' ||
              loan['returned_date'] != null;

          if (!isReturned) {
            int daysLeft = _calculateDaysLeft(loan['due_date']); // Changé de return_date à due_date
            bool isUrgent = daysLeft <= 3;
            bool isOverdue = daysLeft < 0;

            if (isOverdue) overdueBooks++;
            if (isUrgent) toReturnSoon++;

            //  Gérer les deux cas : book est un ID ou un objet
            String title = 'Sans titre';
            String author = 'Auteur inconnu';
            
            if (loan['book'] is Map) {
              // Si book est un objet complet
              title = loan['book']?['title'] ?? 'Sans titre';
              author = loan['book']?['author'] ?? 'Auteur inconnu';
            } else {
              // Si book est juste un ID, chercher dans booksArray
              int bookId = loan['book'];
              var book = booksArray.firstWhere(
                (b) => b['id'] == bookId,
                orElse: () => null,
              );
              if (book != null) {
                title = book['title'] ?? 'Sans titre';
                author = book['author'] ?? 'Auteur inconnu';
              }
            }

            currentLoans.add({
              'id': loan['id'],
              'title': title,
              'author': author,
              'daysLeft': daysLeft,
              'returnDate': _formatDate(loan['due_date']),
              'borrowDate': _formatDate(loan['borrow_date']),
              'status': _getStatus(loan['status'], daysLeft),
              'isUrgent': isUrgent,
              'isOverdue': isOverdue,
            });
          }
        }

        suggestions = [];
        for (var book in booksArray.take(3)) {
          bool isAvailable = (book['available_copies'] ?? 0) > 0 || 
                             book['status'] == 'available';
          
          suggestions.add({
            'id': book['id'],
            'title': book['title'] ?? 'Sans titre',
            'author': book['author'] ?? 'Auteur inconnu',
            'imageIcon': book['image_icon'] ?? '📖',
            'rating': (book['rating'] ?? 0).toDouble(),
            'available': isAvailable,
            'availableCopies': book['available_copies'] ?? 0,
          });
        }

        isLoading = false;
      });
    } else {
      setState(() {
        errorMessage =
            'Erreur lors du chargement des données (${loansResponse.statusCode})';
        isLoading = false;
      });
    }
  } catch (e) {
    setState(() {
      errorMessage = 'Erreur de connexion: $e';
      isLoading = false;
    });
  }
}

 

 /// Emprunter un livre - ENDPOINT CORRECT
Future<void> _borrowBook(Map<String, dynamic> book) async {
  try {
    // Calculer la date de retour (14 jours par défaut)
    DateTime dueDate = DateTime.now().add(const Duration(days: 14));
    String dueDateString = dueDate.toIso8601String().split('T')[0]; // Format: YYYY-MM-DD

    final payload = {
      'book': book['id'],           // ✅ 'book' pas 'book_id'
      'user': userId,                    // ✅ 'user' pas 'user_id'
      'due_date': dueDateString,    // ✅ REQUIS (date de retour)
    };
    
    print('📤 Borrow payload: $payload');
    
    final response = await http.post(
      Uri.parse('${loansApiUrl}'),  // POST /api/loans/
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    );

    if (mounted) {
      print('🔍 Borrow - Status: ${response.statusCode}');
      print('🔍 Borrow - Body: ${response.body}');
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        _showSuccessSnackBar('${book['title']} emprunté ✓');
        _fetchHomeData();
      } else {
        _showErrorSnackBar('Erreur: ${response.body}');
      }
    }
  } catch (e) {
    _showErrorSnackBar('Erreur: $e');
  }
}

/// Retourner un emprunt
Future<void> _returnLoan(Map<String, dynamic> loan) async {
  try {
    final response = await http.post(
      Uri.parse('$loansApiUrl${loan['id']}/return/'),
      headers: {'Content-Type': 'application/json'},
    );

    if (mounted) {
      print('🔍 Return - Status: ${response.statusCode}');
      print('🔍 Return - Body: ${response.body}');
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        _showSuccessSnackBar('${loan['title']} retourné ✓');
        _fetchHomeData();
      } else {
        _showErrorSnackBar('Erreur: ${response.body}');
      }
    }
  } catch (e) {
    _showErrorSnackBar('Erreur: $e');
  }
}

/// Renouveler un emprunt
Future<void> _renewLoan(Map<String, dynamic> loan) async {
  try {
    final response = await http.post(
      Uri.parse('$loansApiUrl${loan['id']}/renew/'),
      headers: {'Content-Type': 'application/json'},
    );

    if (mounted) {
      print('🔍 Renew - Status: ${response.statusCode}');
      print('🔍 Renew - Body: ${response.body}');
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        _showSuccessSnackBar('${loan['title']} renouvelé ✓');
        _fetchHomeData();
      } else {
        _showErrorSnackBar('Erreur: ${response.body}');
      }
    }
  } catch (e) {
    _showErrorSnackBar('Erreur: $e');
  }
}
  /// Calculer les jours restants
  int _calculateDaysLeft(dynamic returnDate) {
    if (returnDate == null) return 0;
    try {
      if (returnDate is String) {
        DateTime parsedDate = DateTime.parse(returnDate);
        Duration difference = parsedDate.difference(DateTime.now());
        return difference.inDays;
      }
      return 0;
    } catch (e) {
      return 0;
    }
  }

  /// Obtenir le statut
  String _getStatus(dynamic status, int daysLeft) {
    if (daysLeft < 0) return 'En retard';
    if (daysLeft <= 3) return 'À retourner rapidement';
    return 'En cours';
  }

  /// Formater une date
  String _formatDate(dynamic date) {
    if (date == null) return 'Non défini';
    try {
      if (date is String) {
        DateTime parsedDate = DateTime.parse(date);
        return '${parsedDate.day} ${_getMonthName(parsedDate.month)} ${parsedDate.year}';
      }
      return date.toString();
    } catch (e) {
      return date.toString();
    }
  }

  /// Obtenir le nom du mois en français
  String _getMonthName(int month) {
    const months = [
      'Janvier',
      'Février',
      'Mars',
      'Avril',
      'Mai',
      'Juin',
      'Juillet',
      'Août',
      'Septembre',
      'Octobre',
      'Novembre',
      'Décembre'
    ];
    return months[month - 1];
  }

  /// Afficher un message de succès
  void _showSuccessSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  /// Afficher un message d'erreur
  void _showErrorSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Appuyez à nouveau pour quitter')),
        );
        return false;
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F5F5),
        body: SafeArea(
          child: isLoading
              ? _buildLoadingState()
              : errorMessage != null
                  ? _buildErrorState()
                  : SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: Column(
                        children: [
                          // === HEADER AVEC GRADIENT ===
                          _buildHeader(),

                          const SizedBox(height: 20),

                          // === CONTENU PRINCIPAL ===
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // === SECTION EMPRUNTS EN COURS ===
                                _buildSectionHeader(
                                  title:
                                      'Mes emprunts en cours (${currentLoans.length})',
                                  onSeeAll: () => _navigateTo(2),
                                ),
                                const SizedBox(height: 12),
                                currentLoans.isEmpty
                                    ? _buildEmptyLoanState()
                                    : _buildLoansList(),

                                const SizedBox(height: 24),

                                // === SECTION ACTIONS RAPIDES ===
                                _buildSectionHeader(title: 'Actions rapides'),
                                const SizedBox(height: 12),
                                _buildQuickActions(),

                                const SizedBox(height: 24),

                                // === SECTION SUGGESTIONS ===
                                _buildSectionHeader(
                                  title: 'Suggestions pour vous',
                                  onSeeAll: () => _navigateTo(1),
                                ),
                                const SizedBox(height: 12),
                                suggestions.isEmpty
                                    ? _buildEmptySuggestionsState()
                                    : _buildSuggestionsList(),

                                // === SECTION ALERTES (Si retards) ===
                                if (overdueBooks > 0) ...[
                                  const SizedBox(height: 24),
                                  _buildAlertSection(),
                                ],

                                const SizedBox(height: 30),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
        ),
        // === BOTTOM NAVIGATION BAR ===
        bottomNavigationBar: _buildBottomNavigation(),
      ),
    );
  }

  // === ÉTATS DE CHARGEMENT ===

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF667eea)),
          ),
          const SizedBox(height: 16),
          const Text('Chargement de l\'accueil...'),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 64,
            color: Colors.red[400],
          ),
          const SizedBox(height: 16),
          Text(
            'Erreur',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.red[400],
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              errorMessage ?? 'Une erreur est survenue',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600]),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _fetchHomeData,
            icon: const Icon(Icons.refresh),
            label: const Text('Réessayer'),
          ),
        ],
      ),
    );
  }

  /// === WIDGETS PRINCIPAUX ===

  /// 1. HEADER AVEC GRADIENT ET PROFIL
   Widget _buildHeader() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF667eea), Color(0xFF764ba2)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Bienvenue',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    displayName, // <-- Utilisation de fullName
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    userEmail,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.6),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              GestureDetector(
                onTap: () => _navigateTo(4),
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: const CircleAvatar(
                    radius: 24,
                    backgroundColor: Colors.white,
                    child: Icon(
                      Icons.person,
                      color: Color(0xFF667eea),
                      size: 28,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildStatCard(
                icon: Icons.book,
                value: totalBorrows.toString(),
                label: 'Emprunts',
                color: Colors.orange,
              ),
              _buildStatCard(
                icon: Icons.calendar_today,
                value: toReturnSoon.toString(),
                label: 'À retourner',
                color: Colors.red,
              ),
              _buildStatCard(
                icon: Icons.bookmark,
                value: reservations.toString(),
                label: 'Réservation',
                color: Colors.green,
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 2. EN-TÊTE DE SECTION
  Widget _buildSectionHeader({required String title, VoidCallback? onSeeAll}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Color(0xFF333333),
          ),
        ),
        if (onSeeAll != null)
          GestureDetector(
            onTap: onSeeAll,
            child: const Text(
              'Voir tous',
              style: TextStyle(
                fontSize: 13,
                color: Color(0xFF667eea),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
      ],
    );
  }

  /// 3. LISTE DES EMPRUNTS
  Widget _buildLoansList() {
    return Column(
      children: [
        ...currentLoans.asMap().entries.map((entry) {
          int index = entry.key;
          Map<String, dynamic> loan = entry.value;
          return Column(
            children: [
              _buildLoanCard(loan: loan),
              if (index < currentLoans.length - 1) const SizedBox(height: 12),
            ],
          );
        }),
      ],
    );
  }

  /// 4. CARTE D'EMPRUNT DÉTAILLÉE
  Widget _buildLoanCard({required Map<String, dynamic> loan}) {
    bool isUrgent = loan['isUrgent'] ?? false;
    bool isOverdue = loan['isOverdue'] ?? false;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isOverdue
              ? Colors.red[200]!
              : isUrgent
                  ? Colors.orange[200]!
                  : Colors.grey[200]!,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.grey[300]!.withOpacity(0.5),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      loan['title'],
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF333333),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      loan['author'],
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: isOverdue
                      ? Colors.red[50]
                      : isUrgent
                          ? Colors.orange[50]
                          : Colors.green[50],
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  isOverdue ? '${loan['daysLeft'].abs()}j' : '${loan['daysLeft']}j',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: isOverdue
                        ? Colors.red
                        : isUrgent
                            ? Colors.orange
                            : Colors.green,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.calendar_today, size: 14, color: Colors.grey[500]),
              const SizedBox(width: 6),
              Text(
                'Retour: ${loan['returnDate']}',
                style: TextStyle(fontSize: 11, color: Colors.grey[600]),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => _renewLoan(loan),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF667eea).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'Renouveler',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF667eea),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: GestureDetector(
                  onTap: () => _returnLoan(loan),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'Retourner',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF333333),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 5. ACTIONS RAPIDES
  Widget _buildQuickActions() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _buildActionCard(
          icon: Icons.search,
          label: 'Rechercher',
          color: const Color(0xFF667eea),
          onTap: () => _navigateTo(1),
        ),
        _buildActionCard(
          icon: Icons.bookmark_border,
          label: 'Réservations',
          color: const Color(0xFF764ba2),
          onTap: () => _navigateTo(3),
        ),
        _buildActionCard(
          icon: Icons.refresh,
          label: 'Rafraîchir',
          color: const Color(0xFFF39C12),
          onTap: _fetchHomeData,
        ),
        _buildActionCard(
          icon: Icons.settings,
          label: 'Paramètres',
          color: const Color(0xFF27AE60),
          onTap: () => _navigateTo(4),
        ),
      ],
    );
  }

  /// 6. CARTE D'ACTION
  Widget _buildActionCard({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.3), width: 1.5),
          ),
          child: Column(
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(height: 8),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 7. LISTE DES SUGGESTIONS
  Widget _buildSuggestionsList() {
    return Column(
      children: [
        ...suggestions.asMap().entries.map((entry) {
          int index = entry.key;
          Map<String, dynamic> suggestion = entry.value;
          return Column(
            children: [
              _buildSuggestionCard(suggestion: suggestion),
              if (index < suggestions.length - 1) const SizedBox(height: 12),
            ],
          );
        }),
      ],
    );
  }
/// Réserver un livre
/// Réserver un livre
Future<void> _reserveBook(Map<String, dynamic> book) async {
  try {
    final now = DateTime.now();
    
    // Vérifier d'abord si une réservation existe déjà
    final checkResponse = await http.get(
      Uri.parse('https://libratech-backend.onrender.com/api/reservations/'),
      headers: {'Content-Type': 'application/json'},
    );

    if (checkResponse.statusCode == 200) {
      final jsonData = jsonDecode(checkResponse.body);
      List<dynamic> reservationsData;
      
      if (jsonData is Map<String, dynamic>) {
        reservationsData = jsonData['results'] ?? [];
      } else {
        reservationsData = jsonData;
      }

      // Vérifier si l'utilisateur a déjà une réservation pour ce livre
      bool alreadyReserved = false;
      for (var reservation in reservationsData) {
        if (reservation is Map<String, dynamic>) {
          int reservationUserId = reservation['user'] is Map 
              ? reservation['user']['id'] ?? 0
              : reservation['user'] ?? 0;
          
          int reservationBookId = reservation['book'] is Map
              ? reservation['book']['id'] ?? 0
              : reservation['book'] ?? 0;
          
          String status = (reservation['status'] ?? '').toString().toLowerCase();
          
          // Vérifier si c'est la même combinaison user+book et non terminée
          if (reservationUserId == userId && 
              reservationBookId == book['id'] &&
              (status == 'pending' || status == 'en attente' || status == 'active')) {
            alreadyReserved = true;
            break;
          }
        }
      }

      if (alreadyReserved) {
        if (mounted) {
          _showErrorSnackBar('Vous avez déjà réservé ce livre');
        }
        return;
      }
    }

    // Si aucune réservation existante, créer la nouvelle réservation
    final payload = {
      'book': book['id'],
      'user': userId,
      'pickup_deadline': now.add(const Duration(days: 7)).toIso8601String(),
      'status': 'pending', // Ajouter le statut explicitement
    };
    
    print('📤 Reserve payload: $payload');
    
    final response = await http.post(
      Uri.parse('https://libratech-backend.onrender.com/api/reservations/'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    );

    if (mounted) {
      print('🔍 Reserve - Status: ${response.statusCode}');
      print('🔍 Reserve - Body: ${response.body}');
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        _showSuccessSnackBar('${book['title']} réservé ✓');
        _fetchHomeData();
      } else {
        final errorData = jsonDecode(response.body);
        if (errorData.containsKey('non_field_errors')) {
          // Erreur de doublon détectée par le backend
          _showErrorSnackBar('Vous avez déjà réservé ce livre');
        } else {
          _showErrorSnackBar('Erreur: ${response.body}');
        }
      }
    }
  } catch (e) {
    _showErrorSnackBar('Erreur: $e');
  }
}
  /// 8. CARTE DE SUGGESTION
  Widget _buildSuggestionCard({required Map<String, dynamic> suggestion}) {
  return Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      boxShadow: [
        BoxShadow(
          color: Colors.grey[300]!.withOpacity(0.5),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ],
    ),
    child: Row(
      children: [
        Container(
          width: 60,
          height: 80,
          decoration: BoxDecoration(
            color: const Color(0xFF667eea).withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text(suggestion['imageIcon'],
                style: const TextStyle(fontSize: 32)),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                suggestion['title'],
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF333333),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                suggestion['author'],
                style: TextStyle(fontSize: 11, color: Colors.grey[600]),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(Icons.star, size: 14, color: Colors.amber[700]),
                  const SizedBox(width: 4),
                  Text(
                    suggestion['rating'].toString(),
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF333333),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: suggestion['available']
                          ? Colors.green[50]
                          : Colors.red[50],
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      suggestion['available'] ? 'Disponible' : 'Indisponible',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: suggestion['available']
                            ? Colors.green
                            : Colors.red,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        // ✅ BOUTONS D'ACTIONS (Emprunter + Réserver)
        Column(
          children: [
            // Bouton Emprunter
            GestureDetector(
              onTap: () => suggestion['available']
                  ? _borrowBook(suggestion)
                  : _showErrorSnackBar('Ce livre n\'est pas disponible'),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: suggestion['available']
                      ? const Color(0xFF667eea).withOpacity(0.2)
                      : Colors.grey[200],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.add_circle,
                  color: suggestion['available']
                      ? const Color(0xFF667eea)
                      : Colors.grey[400],
                  size: 22,
                ),
              ),
            ),
            const SizedBox(height: 8),
            // ✅ NOUVEAU: Bouton Réserver
            GestureDetector(
  onTap: () => _reserveBook(suggestion),  // ✅ Pas de condition, réserver directement
  child: Container(
    padding: const EdgeInsets.all(8),
    decoration: BoxDecoration(
      color: Colors.orange.withOpacity(0.2),  // ✅ Toujours actif
      borderRadius: BorderRadius.circular(8),
    ),
    child: const Icon(
      Icons.bookmark_border,
      color: Colors.orange,
      size: 22,
    ),
  ),
),
          ],
        ),
      ],
    )
  );
}

  /// 9. SECTION ALERTES
  Widget _buildAlertSection() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.red[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red[200]!, width: 1.5),
      ),
      child: Row(
        children: [
          Icon(Icons.warning, color: Colors.red[700], size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Livres en retard !',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Colors.red[900],
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Vous avez $overdueBooks livre(s) à retourner en retard.',
                  style: TextStyle(fontSize: 11, color: Colors.red[700]),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => _navigateTo(2),
            child: Text(
              'Retourner',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Colors.red[700],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 10. CARTE DE STATISTIQUE
  Widget _buildStatCard({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }

  /// 11. EMPTY STATE EMPRUNTS
  Widget _buildEmptyLoanState() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 30),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey[300]!.withOpacity(0.5),
            blurRadius: 8,
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(Icons.book_outlined, size: 48, color: Colors.grey[400]),
          const SizedBox(height: 12),
          Text(
            'Aucun emprunt en cours',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Explorez le catalogue pour emprunter des livres',
            style: TextStyle(fontSize: 12, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  /// 12. EMPTY STATE SUGGESTIONS
  Widget _buildEmptySuggestionsState() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 30),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey[300]!.withOpacity(0.5),
            blurRadius: 8,
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(Icons.library_books_outlined,
              size: 48, color: Colors.grey[400]),
          const SizedBox(height: 12),
          Text(
            'Aucune suggestion disponible',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  /// 13. BOTTOM NAVIGATION BAR
  Widget _buildBottomNavigation() {
    return BottomNavigationBar(
      currentIndex: _selectedIndex,
      type: BottomNavigationBarType.fixed,
      backgroundColor: Colors.white,
      selectedItemColor: const Color(0xFF667eea),
      unselectedItemColor: Colors.grey[400],
      elevation: 8,
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.home_outlined),
          activeIcon: Icon(Icons.home),
          label: 'Accueil',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.library_books_outlined),
          activeIcon: Icon(Icons.library_books),
          label: 'Livres',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.book_outlined),
          activeIcon: Icon(Icons.book),
          label: 'Emprunts',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.bookmark_outline),
          activeIcon: Icon(Icons.bookmark),
          label: 'Réservations',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.person_outline),
          activeIcon: Icon(Icons.person),
          label: 'Profil',
        ),
      ],
      onTap: (index) {
        setState(() {
          _selectedIndex = index;
        });
        _navigateTo(index);
      },
    );
  }

  /// === NAVIGATION ===

  void _navigateTo(int index) {
    setState(() {
      _selectedIndex = index;
    });

    switch (index) {
      case 0:
        break;
      case 1:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const BooksListScreen()),
        );
        break;
      case 2:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const LoansScreen()),
        );
        break;
      case 3:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const ReservationsScreen(),
          ),
        );
        break;
      case 4:
        Navigator.push(
          context,
            MaterialPageRoute(
            builder: (context) => ProfileScreen(
              userName: displayName,
              userEmail: userEmail,
            ),
            ),
        );
        break;
    }
  }
}
