import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class LoansScreen extends StatefulWidget {
  const LoansScreen({Key? key}) : super(key: key);

  @override
  State<LoansScreen> createState() => _LoansScreenState();
}

class _LoansScreenState extends State<LoansScreen>
    with SingleTickerProviderStateMixin {
  // === API CONFIGURATION ===
  final String apiUrl = 'https://libratech-backend.onrender.com/api/loans/';
  final String baseUrl = 'https://libratech-backend.onrender.com';

  // === CONTRÔLEURS ===
  late TabController tabController;

  // === DONNÉES ===
  bool isLoading = true;
  String? errorMessage;
  List<Map<String, dynamic>> currentLoans = [];
  List<Map<String, dynamic>> pastLoans = [];

  // === STATISTIQUES ===
  int totalBorrows = 0;
  int currentBorrowCount = 0;
  int overdueBooksCount = 0;
  double totalPagesRead = 0;

  @override
  void initState() {
    super.initState();
    tabController = TabController(length: 2, vsync: this);
    _fetchLoans();
  }

  @override
  void dispose() {
    tabController.dispose();
    super.dispose();
  }

  // === API CALLS ===

  /// Récupérer les emprunts depuis le backend
 Future<void> _fetchLoans() async {
  setState(() {
    isLoading = true;
    errorMessage = null;
  });

  try {
    final response = await http.get(Uri.parse(apiUrl));

    if (response.statusCode == 200) {
      final jsonData = jsonDecode(response.body);
      
      print('🔍 LOANS API RESPONSE: $jsonData');

      List<dynamic> loansData =
          jsonData is List ? jsonData : jsonData['results'] ?? [];

      setState(() {
        currentLoans = [];
        pastLoans = [];
        totalPagesRead = 0;
        overdueBooksCount = 0;

        for (var loan in loansData) {
          bool isReturned = loan['status'] == 'returned' ||
              loan['status'] == 'Retourné' ||
              loan['status'] == 'Retourné en avance' ||
              loan['returned_date'] != null;

          int daysLeft = _calculateDaysLeft(loan['due_date']); // ✅ Changé de return_date à due_date
          bool isUrgent = daysLeft <= 3 && daysLeft > 0;
          bool isOverdue = daysLeft < 0;

          // ✅ Gérer les deux cas : book est un ID ou un objet
          String title = 'Sans titre';
          String author = 'Auteur inconnu';
          String imageIcon = '📖';
          int totalPages = 0;

          if (loan['book'] is Map) {
            // Si book est un objet complet
            title = loan['book']?['title'] ?? 'Sans titre';
            author = loan['book']?['author'] ?? 'Auteur inconnu';
            imageIcon = loan['book']?['image_icon'] ?? '📖';
            totalPages = loan['book']?['pages'] ?? 0;
          } else {
            // Si book est juste un ID, afficher juste l'ID pour le moment
            title = 'Livre ID: ${loan['book']}';
            author = 'Détails non disponibles';
          }

          Map<String, dynamic> loanData = {
            'id': loan['id'] ?? 0,
            'title': title,
            'author': author,
            'imageIcon': imageIcon,
            'borrowDate': _formatDate(loan['borrow_date']),
            'returnDate': _formatDate(loan['due_date']),
            'daysLeft': daysLeft,
            'status': _getStatus(loan['status'], daysLeft),
            'totalPages': totalPages,
            'isUrgent': isUrgent,
            'isOverdue': isOverdue,
            'returnedDate': loan['returned_date'] != null
                ? _formatDate(loan['returned_date'])
                : null,
            'returnReason': loan['return_reason'],
          };

          if (isReturned) {
            pastLoans.add(loanData);
          } else {
            currentLoans.add(loanData);
          }

          if (!isReturned) {
            totalPagesRead += (loanData['totalPages'] as num).toDouble();
            if (isOverdue) overdueBooksCount++;
          }
        }

        totalBorrows = loansData.length;
        currentBorrowCount = currentLoans.length;

        isLoading = false;
      });
    } else {
      setState(() {
        errorMessage = 'Erreur: ${response.statusCode}';
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

  /// Renouveler un emprunt
  Future<void> _renewLoan(Map<String, dynamic> loan) async {
  try {
    final response = await http.post(
      Uri.parse('$apiUrl${loan['id']}/renew/'),  // ✅ Cet endpoint existe
      headers: {'Content-Type': 'application/json'},
    );

    if (mounted) {
      print('🔍 Renew - Status: ${response.statusCode}');
      print('🔍 Renew - Body: ${response.body}');
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        _showSuccessSnackBar('${loan['title']} renouvelé ✓');
        _fetchLoans();
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
      Uri.parse('$apiUrl${loan['id']}/return_book/'),
      headers: {'Content-Type': 'application/json'},
    );

    if (mounted) {
      if (response.statusCode == 200 || response.statusCode == 201) {
        _showSuccessSnackBar('${loan['title']} retourné ✓');
        _fetchLoans();
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

  /// Obtenir le statut basé sur les jours restants
  String _getStatus(dynamic status, int daysLeft) {
    if (status != null) {
      String statusStr = status.toString().toLowerCase();
      if (statusStr.contains('returned') || statusStr.contains('retourné')) {
        return 'Retourné';
      }
    }

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
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: SafeArea(
        child: isLoading
            ? _buildLoadingState()
            : errorMessage != null
                ? _buildErrorState()
                : Column(
                    children: [
                      // === HEADER ===
                      _buildHeader(),

                      const SizedBox(height: 16),

                      // === STATISTIQUES ===
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: _buildStatsSection(),
                      ),

                      const SizedBox(height: 16),

                      // === TABS ===
                      _buildTabBar(),

                      const SizedBox(height: 12),

                      // === CONTENU DES TABS ===
                      Expanded(
                        child: TabBarView(
                          controller: tabController,
                          children: [
                            // Tab 1: Emprunts en cours
                            _buildCurrentLoansTab(),

                            // Tab 2: Historique
                            _buildPastLoansTab(),
                          ],
                        ),
                      ),
                    ],
                  ),
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
          const Text('Chargement des emprunts...'),
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
            onPressed: _fetchLoans,
            icon: const Icon(Icons.refresh),
            label: const Text('Réessayer'),
          ),
        ],
      ),
    );
  }

  /// === WIDGETS PRINCIPAUX ===

  /// 1. HEADER
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
                  const Text(
                    'Mes Emprunts',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Gestion des livres',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              GestureDetector(
                onTap: _fetchLoans,
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white.withOpacity(0.3)),
                  ),
                  child: const Icon(
                    Icons.book_outlined,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Total: $totalBorrows emprunts • $currentBorrowCount en cours',
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  /// 2. SECTION STATISTIQUES
  Widget _buildStatsSection() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildStatCard(
            icon: Icons.book,
            value: totalBorrows.toString(),
            label: 'Total',
            color: const Color(0xFF667eea),
          ),
          const SizedBox(width: 12),
          _buildStatCard(
            icon: Icons.bookmark,
            value: currentBorrowCount.toString(),
            label: 'En cours',
            color: Colors.orange,
          ),
          const SizedBox(width: 12),
          _buildStatCard(
            icon: Icons.warning,
            value: overdueBooksCount.toString(),
            label: 'En retard',
            color: Colors.red,
          ),
          const SizedBox(width: 12),
          _buildStatCard(
            icon: Icons.pages,
            value: totalPagesRead.toStringAsFixed(0),
            label: 'Pages lues',
            color: Colors.green,
          ),
        ],
      ),
    );
  }

  /// 3. BARRE D'ONGLETS
  Widget _buildTabBar() {
    return Container(
      color: Colors.white,
      child: TabBar(
        controller: tabController,
        labelColor: const Color(0xFF667eea),
        unselectedLabelColor: Colors.grey[600],
        labelStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
        ),
        unselectedLabelStyle: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
        indicatorColor: const Color(0xFF667eea),
        indicatorWeight: 3,
        tabs: [
          Tab(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.bookmark_outline),
                const SizedBox(width: 6),
                const Text('En cours'),
                const SizedBox(width: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF667eea).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    currentBorrowCount.toString(),
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF667eea),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Tab(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.history),
                const SizedBox(width: 6),
                const Text('Historique'),
                const SizedBox(width: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.grey[300]!.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    pastLoans.length.toString(),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[700],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 4. TAB EMPRUNTS EN COURS
  Widget _buildCurrentLoansTab() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: currentLoans.isEmpty
          ? _buildEmptyState(
              icon: Icons.book_outlined,
              title: 'Aucun emprunt en cours',
              subtitle: 'Explorez notre catalogue pour emprunter des livres',
            )
          : ListView.builder(
              physics: const BouncingScrollPhysics(),
              itemCount: currentLoans.length,
              itemBuilder: (context, index) {
                return Column(
                  children: [
                    _buildLoanCard(
                      loan: currentLoans[index],
                      isCurrent: true,
                    ),
                    if (index < currentLoans.length - 1)
                      const SizedBox(height: 12),
                  ],
                );
              },
            ),
    );
  }

  /// 5. TAB HISTORIQUE
  Widget _buildPastLoansTab() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: pastLoans.isEmpty
          ? _buildEmptyState(
              icon: Icons.history,
              title: 'Aucun historique',
              subtitle: 'Votre historique d\'emprunts apparaîtra ici',
            )
          : ListView.builder(
              physics: const BouncingScrollPhysics(),
              itemCount: pastLoans.length,
              itemBuilder: (context, index) {
                return Column(
                  children: [
                    _buildPastLoanCard(
                      loan: pastLoans[index],
                    ),
                    if (index < pastLoans.length - 1)
                      const SizedBox(height: 12),
                  ],
                );
              },
            ),
    );
  }

  /// === WIDGETS AUXILIAIRES ===

  /// Carte de statistique
  Widget _buildStatCard({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.grey[300]!.withOpacity(0.5),
            blurRadius: 6,
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF333333),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  /// Carte d'emprunt en cours
  Widget _buildLoanCard({
    required Map<String, dynamic> loan,
    required bool isCurrent,
  }) {
    bool isUrgent = loan['isUrgent'] ?? false;
    bool isOverdue = loan['isOverdue'] ?? false;

    return Container(
      padding: const EdgeInsets.all(14),
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
            blurRadius: 6,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Titre et jours restants
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            loan['title'],
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF333333),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      loan['author'],
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
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
                  isOverdue ? '${loan['daysLeft'].abs()}j en retard' : '${loan['daysLeft']}j',
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

          // Icône et dates
          Row(
            children: [
              Text(
                loan['imageIcon'],
                style: const TextStyle(fontSize: 28),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Emprunt',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[600],
                          ),
                        ),
                        Text(
                          'Retour',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          loan['borrowDate'],
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF333333),
                          ),
                        ),
                        Text(
                          loan['returnDate'],
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: isOverdue ? Colors.red : Colors.grey[700],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Barre de progression
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (loan['daysLeft'] / 14).clamp(0.0, 1.0),
              minHeight: 6,
              backgroundColor: Colors.grey[200],
              valueColor: AlwaysStoppedAnimation<Color>(
                isOverdue
                    ? Colors.red
                    : isUrgent
                        ? Colors.orange
                        : Colors.green,
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Boutons d'action
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => _showRenewDialog(loan),
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
                  onTap: () => _showReturnDialog(loan),
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

  /// Carte d'emprunt passé
  Widget _buildPastLoanCard({
    required Map<String, dynamic> loan,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey[300]!.withOpacity(0.5),
            blurRadius: 6,
          ),
        ],
      ),
      child: Row(
        children: [
          // Image
          Text(
            loan['imageIcon'],
            style: const TextStyle(fontSize: 32),
          ),
          const SizedBox(width: 12),

          // Infos
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  loan['title'],
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
                  loan['author'],
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(Icons.check_circle, size: 14, color: Colors.green),
                    const SizedBox(width: 6),
                    Text(
                      'Retourné le ${loan['returnedDate']}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.green,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Pages
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${loan['totalPages']}',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF667eea),
                ),
              ),
              Text(
                'pages',
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// État vide
  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  /// === DIALOGS ===

  void _showRenewDialog(Map<String, dynamic> loan) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Renouveler l\'emprunt'),
        content: Text('Voulez-vous renouveler "${loan['title']}" ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _renewLoan(loan);
            },
            child: const Text('Renouveler'),
          ),
        ],
      ),
    );
  }

  void _showReturnDialog(Map<String, dynamic> loan) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Retourner le livre'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Êtes-vous sûr de retourner "${loan['title']}" ?'),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue[200]!),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '📋 Détails du retour :',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.blue[900],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '• Le livre sera supprimé de vos emprunts en cours',
                  style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                ),
                const SizedBox(height: 4),
                Text(
                  '• Il apparaîtra dans votre historique',
                  style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                ),
                const SizedBox(height: 4),
                Text(
                  '• Le livre redevient disponible pour les autres',
                  style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annuler'),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(context);
            _returnLoan(loan);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
          ),
          child: const Text('Confirmer le retour'),
        ),
      ],
    ),
  );
}
}
