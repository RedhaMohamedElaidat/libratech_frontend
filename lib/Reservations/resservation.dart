import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class ReservationsScreen extends StatefulWidget {
  const ReservationsScreen({Key? key}) : super(key: key);

  @override
  State<ReservationsScreen> createState() => _ReservationsScreenState();
}

class _ReservationsScreenState extends State<ReservationsScreen> {
  // === API CONFIGURATION ===
  final String apiUrl = 'https://libratech-backend.onrender.com/api/reservations/';
  final String baseUrl = 'https://libratech-backend.onrender.com';

  // === DONNÉES ===
  bool isLoading = true;
  String? errorMessage;
  List<Map<String, dynamic>> pendingReservations = [];
  List<Map<String, dynamic>> completedReservations = [];

  // === STATISTIQUES ===
  int totalReservations = 0;
  int completedCount = 0;
  int pendingCount = 0;

  @override
  void initState() {
    super.initState();
    _fetchReservations();
  }

  // === API CALLS ===

  /// Récupérer les réservations depuis le backend
Future<void> _fetchReservations() async {
  setState(() {
    isLoading = true;
    errorMessage = null;
  });

  try {
    final response = await http.get(
      Uri.parse('https://libratech-backend.onrender.com/api/reservations/'),
      headers: {'Content-Type': 'application/json'},
    );

    if (response.statusCode == 200) {
      final jsonData = jsonDecode(response.body);

      // Vérifier si c'est une Map ou une List
      List<dynamic> reservationsData;
      
      if (jsonData is Map<String, dynamic>) {
        // Si l'API retourne un objet avec une clé 'results'
        if (jsonData.containsKey('results')) {
          reservationsData = jsonData['results'] as List<dynamic>;
        } else if (jsonData.containsKey('data')) {
          // Ou une clé 'data'
          reservationsData = jsonData['data'] as List<dynamic>;
        } else if (jsonData.containsKey('reservations')) {
          // Ou une clé 'reservations'
          reservationsData = jsonData['reservations'] as List<dynamic>;
        } else {
          // Afficher toutes les clés pour debugging
          print('Clés disponibles dans la réponse: ${jsonData.keys}');
          throw Exception('Format de réponse API inconnu');
        }
      } else if (jsonData is List<dynamic>) {
        // Si l'API retourne directement une liste
        reservationsData = jsonData;
      } else {
        throw Exception('Format de réponse API invalide');
      }

      // Pour debugging - afficher la structure
      print('Nombre de réservations: ${reservationsData.length}');
      if (reservationsData.isNotEmpty) {
        print('Première réservation: ${reservationsData.first}');
      }

      setState(() {
        pendingReservations = [];
        completedReservations = [];

        for (var res in reservationsData) {
          if (res is! Map<String, dynamic>) continue;
          
          Map<String, dynamic> reservation = {
            'id': res['id'] ?? 0,
            'title': res['book']?['title'] ?? res['title'] ?? 'Sans titre',
            'author': res['book']?['author'] ?? res['author'] ?? 'Auteur inconnu',
            'imageIcon': res['book']?['image_icon'] ?? res['image_icon'] ?? '📖',
            'reservationDate': _formatDate(res['reservation_date']),
            'position': res['position'] ?? 0,
            'estimatedAvailability': res['estimated_availability'] != null
                ? _formatDate(res['estimated_availability'])
                : 'Non défini',
            'status': res['status'] ?? 'En attente',
            'priority': res['priority'] ?? 'Normale',
            'pages': res['book']?['pages'] ?? res['pages'] ?? 0,
            'completedDate': res['completed_date'] != null
                ? _formatDate(res['completed_date'])
                : null,
          };

          String status = (res['status'] ?? '').toString().toLowerCase();
          if (status == 'completed' || status == 'complétée' || status == 'terminee') {
            completedReservations.add(reservation);
          } else {
            pendingReservations.add(reservation);
          }
        }

        totalReservations = reservationsData.length;
        completedCount = completedReservations.length;
        pendingCount = pendingReservations.length;

        isLoading = false;
      });
    } else {
      setState(() {
        errorMessage = 'Erreur HTTP: ${response.statusCode} - ${response.body}';
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

  /// Annuler une réservation
  Future<void> _cancelReservation(Map<String, dynamic> reservation) async {
    try {
      final response = await http.delete(
        Uri.parse('$apiUrl${reservation['id']}/'),
        headers: {'Content-Type': 'application/json'},
      );

      if (mounted) {
        if (response.statusCode == 204 || response.statusCode == 200) {
          _showSuccessSnackBar(
              'Réservation de "${reservation['title']}" annulée ✓');
          _fetchReservations(); // Rafraîchir la liste
        } else {
          _showErrorSnackBar('Erreur lors de l\'annulation');
        }
      }
    } catch (e) {
      _showErrorSnackBar('Erreur: $e');
    }
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
                : SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      children: [
                        // === HEADER ===
                        _buildHeader(),

                        const SizedBox(height: 16),

                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // === STATISTIQUES ===
                              _buildStatsSection(),

                              const SizedBox(height: 24),

                              // === SECTION RÉSERVATIONS EN ATTENTE ===
                              _buildSectionTitle(
                                  'Réservations en attente ($pendingCount)'),
                              const SizedBox(height: 12),
                              pendingReservations.isEmpty
                                  ? _buildEmptyState(
                                      icon: Icons.bookmark_outline,
                                      title: 'Aucune réservation',
                                      subtitle:
                                          'Vous n\'avez pas de réservations en attente',
                                    )
                                  : _buildPendingReservationsList(),

                              const SizedBox(height: 24),

                              // === SECTION RÉSERVATIONS COMPLÉTÉES ===
                              _buildSectionTitle(
                                  'Réservations complétées ($completedCount)'),
                              const SizedBox(height: 12),
                              completedReservations.isEmpty
                                  ? _buildEmptyState(
                                      icon: Icons.check_circle_outline,
                                      title: 'Aucune réservation complétée',
                                      subtitle:
                                          'Vos réservations terminées apparaîtront ici',
                                    )
                                  : _buildCompletedReservationsList(),

                              const SizedBox(height: 30),
                            ],
                          ),
                        ),
                      ],
                    ),
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
          const Text('Chargement des réservations...'),
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
            onPressed: _fetchReservations,
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
                    'Réservations',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Mes réservations',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              GestureDetector(
                onTap: _fetchReservations,
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white.withOpacity(0.3)),
                  ),
                  child: const Icon(
                    Icons.bookmark,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Total: $totalReservations réservations • $pendingCount en attente',
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
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            icon: Icons.bookmark,
            value: totalReservations.toString(),
            label: 'Total',
            color: const Color(0xFF667eea),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            icon: Icons.schedule,
            value: pendingCount.toString(),
            label: 'En attente',
            color: Colors.orange,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            icon: Icons.check_circle,
            value: completedCount.toString(),
            label: 'Complétées',
            color: Colors.green,
          ),
        ),
      ],
    );
  }

  /// 3. LISTE RÉSERVATIONS EN ATTENTE
  Widget _buildPendingReservationsList() {
    return Column(
      children: [
        ...pendingReservations.asMap().entries.map((entry) {
          int index = entry.key;
          Map<String, dynamic> reservation = entry.value;
          return Column(
            children: [
              _buildReservationCard(reservation: reservation, isPending: true),
              if (index < pendingReservations.length - 1)
                const SizedBox(height: 12),
            ],
          );
        }).toList(),
      ],
    );
  }

  /// 4. LISTE RÉSERVATIONS COMPLÉTÉES
  Widget _buildCompletedReservationsList() {
    return Column(
      children: [
        ...completedReservations.asMap().entries.map((entry) {
          int index = entry.key;
          Map<String, dynamic> reservation = entry.value;
          return Column(
            children: [
              _buildCompletedReservationCard(reservation: reservation),
              if (index < completedReservations.length - 1)
                const SizedBox(height: 12),
            ],
          );
        }).toList(),
      ],
    );
  }

  /// === WIDGETS AUXILIAIRES ===

  /// Titre de section
  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.bold,
        color: Color(0xFF333333),
      ),
    );
  }

  /// Carte de statistique
  Widget _buildStatCard({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(color: Colors.grey[300]!.withOpacity(0.5), blurRadius: 6),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF333333),
            ),
          ),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
        ],
      ),
    );
  }

  /// Carte de réservation en attente
  Widget _buildReservationCard({
    required Map<String, dynamic> reservation,
    required bool isPending,
  }) {
    Color priorityColor = _getPriorityColor(reservation['priority']);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!, width: 1.5),
        boxShadow: [
          BoxShadow(color: Colors.grey[300]!.withOpacity(0.5), blurRadius: 6),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Titre et position
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      reservation['title'],
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
                      reservation['author'],
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '#${reservation['position']}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Icône et infos
          Row(
            children: [
              Text(
                reservation['imageIcon'],
                style: const TextStyle(fontSize: 32),
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
                          'Réservé',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[600],
                          ),
                        ),
                        Text(
                          'Disponible vers',
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
                          reservation['reservationDate'],
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF333333),
                          ),
                        ),
                        Text(
                          reservation['estimatedAvailability'],
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF333333),
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

          // Priorité et statut
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: priorityColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Priorité ${reservation['priority']}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[700],
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  reservation['status'],
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Colors.orange[700],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Bouton Annuler
          GestureDetector(
            onTap: () => _showCancelDialog(reservation),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: Colors.red[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red[200]!),
              ),
              child: const Text(
                'Annuler la réservation',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.red,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Carte de réservation complétée
  Widget _buildCompletedReservationCard({
    required Map<String, dynamic> reservation,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.grey[300]!.withOpacity(0.5), blurRadius: 6),
        ],
      ),
      child: Row(
        children: [
          // Image
          Text(reservation['imageIcon'], style: const TextStyle(fontSize: 32)),
          const SizedBox(width: 12),

          // Infos
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  reservation['title'],
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
                  reservation['author'],
                  style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(Icons.check_circle, size: 14, color: Colors.green),
                    const SizedBox(width: 6),
                    Text(
                      'Complétée le ${reservation['completedDate']}',
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
                '${reservation['pages']}',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF667eea),
                ),
              ),
              Text(
                'pages',
                style: TextStyle(fontSize: 10, color: Colors.grey[600]),
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
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Column(
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
              style: TextStyle(fontSize: 13, color: Colors.grey[500]),
            ),
          ],
        ),
      ),
    );
  }

  /// === FONCTIONS UTILITAIRES ===

  Color _getPriorityColor(String priority) {
    switch (priority) {
      case 'Haute':
        return Colors.red;
      case 'Normale':
        return Colors.orange;
      case 'Basse':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  /// === DIALOGS ===

  void _showCancelDialog(Map<String, dynamic> reservation) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Annuler la réservation'),
        content: Text(
          'Êtes-vous sûr de vouloir annuler la réservation de "${reservation['title']}" ?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Non, garder'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _cancelReservation(reservation);
            },
            child: const Text('Annuler', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}