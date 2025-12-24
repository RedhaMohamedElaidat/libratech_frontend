import 'package:flutter/material.dart';
import 'package:libratech/login/login.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class ProfileScreen extends StatefulWidget {
  final String userName;
  final String userEmail;

  const ProfileScreen({
    super.key,
    required this.userName,
    required this.userEmail,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  // === DONNÉES UTILISATEUR ===
  late String userName;
  late String userEmail;
  String userPhone = '';
  String userAddress = '';
  String memberId = '';
  String joinDate = '';
  String userRole = '';

  // === STATISTIQUES ===
  int totalBorrows = 0;
  int currentBorrows = 0;
  int totalReservations = 0;
  int totalReviews = 0;
  double accountScore = 0.0;

  // === NOTIFICATIONS ===
  bool emailNotifications = true;
  bool pushNotifications = true;
  bool reminderNotifications = true;

  // === ÉTAT ===
  bool isEditing = false;
  bool showPassword = false;
  bool isLoading = true;
  String? errorMessage;

  // === CONTRÔLEURS ===
  late TextEditingController nameController;
  late TextEditingController emailController;
  late TextEditingController phoneController;
  late TextEditingController addressController;
  late TextEditingController passwordController;
  late TextEditingController newPasswordController;

  @override
  void initState() {
    super.initState();
    userName = widget.userName;
    userEmail = widget.userEmail;
    
    nameController = TextEditingController(text: userName);
    emailController = TextEditingController(text: userEmail);
    phoneController = TextEditingController(text: userPhone);
    addressController = TextEditingController(text: userAddress);
    passwordController = TextEditingController();
    newPasswordController = TextEditingController();

    // Récupérer les données utilisateur
    _fetchUserData();
  }

  /// Récupérer les données utilisateur depuis l'API
 // === MODIFIEZ VOTRE MÉTHODE _fetchUserData ===

/// Récupérer les données utilisateur depuis l'API
Future<void> _fetchUserData() async {
  try {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    // 1. Récupérer les informations de l'utilisateur
    final String usersApiUrl = 'https://libratech-backend.onrender.com/api/users/';
    debugPrint('Tentative de connexion à: $usersApiUrl');
    
    final usersResponse = await http.get(
      Uri.parse(usersApiUrl),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ).timeout(
      const Duration(seconds: 30),
      onTimeout: () => throw Exception('Délai d\'attente dépassé (30s)'),
    );

    if (usersResponse.statusCode == 200) {
      final usersJson = json.decode(usersResponse.body);
      final List<dynamic> users = usersJson['results'] ?? [];
      
      // Rechercher l'utilisateur correspondant
      dynamic userFound;
      for (var user in users) {
        if (user is Map<String, dynamic>) {
          if (user['username'] == userName || 
              user['email'] == userName || 
              user['email'] == userEmail) {
            userFound = user;
            break;
          }
        }
      }

      if (userFound == null) {
        setState(() {
          errorMessage = 'Utilisateur non trouvé';
          isLoading = false;
        });
        return;
      }

      // Extraire les données de base
      setState(() {
        userName = userFound['username'] ?? '';
        userEmail = userFound['email'] ?? '';
        userPhone = userFound['phone'] ?? '';
        userAddress = userFound['address'] ?? '';
        memberId = userFound['id'].toString();
        
        // Formater la date
        String joinDateRaw = userFound['joined_date'] ?? '';
        joinDate = _formatDate(joinDateRaw);
        
        userRole = userFound['role'] ?? 'Lecteur Standard';
        accountScore = (userFound['account_score'] ?? 4.8).toDouble();

        // Mettre à jour les contrôleurs
        nameController.text = userName;
        emailController.text = userEmail;
        phoneController.text = userPhone;
        addressController.text = userAddress;
      });

      // 2. RÉCUPÉRER LES STATISTIQUES SÉPARÉMENT
      await _fetchUserStatistics(userFound['id']);
      
    } else {
      throw Exception('Erreur serveur: ${usersResponse.statusCode}');
    }
  } catch (e) {
    setState(() {
      errorMessage = 'Erreur de connexion: ${e.toString()}';
      isLoading = false;
    });
    debugPrint('Erreur fetch: $e');
  }
}

/// Récupérer les statistiques de l'utilisateur
Future<void> _fetchUserStatistics(int userId) async {
  try {
    // === RÉCUPÉRER LES EMPRUNTS ===
    final loansResponse = await http.get(
      Uri.parse('https://libratech-backend.onrender.com/api/loans/'),
      headers: {'Content-Type': 'application/json'},
    );

    if (loansResponse.statusCode == 200) {
      final loansJson = json.decode(loansResponse.body);
      List<dynamic> loansData;
      
      if (loansJson is Map<String, dynamic>) {
        loansData = loansJson['results'] ?? [];
      } else {
        loansData = loansJson;
      }

      // Filtrer les emprunts de cet utilisateur
      int totalBorrowsCount = 0;
      int currentBorrowsCount = 0;
      
      for (var loan in loansData) {
        if (loan is Map<String, dynamic>) {
          // Vérifier si l'emprunt appartient à cet utilisateur
          int loanUserId = loan['user'] is Map 
              ? loan['user']['id'] ?? 0
              : loan['user'] ?? 0;
          
          if (loanUserId == userId) {
            totalBorrowsCount++;
            
            // Vérifier si c'est un emprunt en cours
            String status = (loan['status'] ?? '').toString().toLowerCase();
            bool isReturned = status == 'returned' || 
                             loan['returned_date'] != null ||
                             status == 'retourné';
            
            if (!isReturned) {
              currentBorrowsCount++;
            }
          }
        }
      }

      // === RÉCUPÉRER LES RÉSERVATIONS ===
      final reservationsResponse = await http.get(
        Uri.parse('https://libratech-backend.onrender.com/api/reservations/'),
        headers: {'Content-Type': 'application/json'},
      );

      int totalReservationsCount = 0;
      
      if (reservationsResponse.statusCode == 200) {
        final reservationsJson = json.decode(reservationsResponse.body);
        List<dynamic> reservationsData;
        
        if (reservationsJson is Map<String, dynamic>) {
          reservationsData = reservationsJson['results'] ?? [];
        } else {
          reservationsData = reservationsJson;
        }

        // Compter les réservations de cet utilisateur
        for (var reservation in reservationsData) {
          if (reservation is Map<String, dynamic>) {
            int reservationUserId = reservation['user'] is Map 
                ? reservation['user']['id'] ?? 0
                : reservation['user'] ?? 0;
            
            if (reservationUserId == userId) {
              totalReservationsCount++;
            }
          }
        }
      }

      // === RÉCUPÉRER LES AVIS ===
      final reviewsResponse = await http.get(
        Uri.parse('https://libratech-backend.onrender.com/api/reviews/'),
        headers: {'Content-Type': 'application/json'},
      );

      int totalReviewsCount = 0;
      
      if (reviewsResponse.statusCode == 200) {
        final reviewsJson = json.decode(reviewsResponse.body);
        List<dynamic> reviewsData;
        
        if (reviewsJson is Map<String, dynamic>) {
          reviewsData = reviewsJson['results'] ?? [];
        } else {
          reviewsData = reviewsJson;
        }

        // Compter les avis de cet utilisateur
        for (var review in reviewsData) {
          if (review is Map<String, dynamic>) {
            int reviewUserId = review['user'] is Map 
                ? review['user']['id'] ?? 0
                : review['user'] ?? 0;
            
            if (reviewUserId == userId) {
              totalReviewsCount++;
            }
          }
        }
      }

      // Mettre à jour l'état avec les statistiques calculées
      if (mounted) {
        setState(() {
          totalBorrows = totalBorrowsCount;
          currentBorrows = currentBorrowsCount;
          totalReservations = totalReservationsCount;
          totalReviews = totalReviewsCount;
          isLoading = false;
        });
      }
      
    } else {
      throw Exception('Erreur lors de la récupération des statistiques');
    }
  } catch (e) {
    debugPrint('Erreur statistiques: $e');
    // En cas d'erreur, mettre des valeurs par défaut
    if (mounted) {
      setState(() {
        totalBorrows = 0;
        currentBorrows = 0;
        totalReservations = 0;
        totalReviews = 0;
        isLoading = false;
      });
    }
  }
}

  /// Formater la date depuis le format ISO
  String _formatDate(String dateString) {
    if (dateString.isEmpty) return '';
    try {
      final DateTime date = DateTime.parse(dateString);
      return '${date.day} ${_getMonthName(date.month)} ${date.year}';
    } catch (e) {
      return dateString;
    }
  }

  /// Obtenir le nom du mois en français
  String _getMonthName(int month) {
    const months = [
      'Janvier', 'Février', 'Mars', 'Avril', 'Mai', 'Juin',
      'Juillet', 'Août', 'Septembre', 'Octobre', 'Novembre', 'Décembre'
    ];
    return months[month - 1];
  }

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    phoneController.dispose();
    addressController.dispose();
    passwordController.dispose();
    newPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        backgroundColor: const Color(0xFFF5F5F5),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF667eea)),
              ),
              const SizedBox(height: 16),
              const Text('Chargement du profil...'),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: _fetchUserData,
                child: const Text('Réessayer'),
              ),
            ],
          ),
        ),
      );
    }

    if (errorMessage != null) {
      return Scaffold(
        backgroundColor: const Color(0xFFF5F5F5),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 60, color: Colors.red[400]),
              const SizedBox(height: 16),
              Text(
                errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _fetchUserData,
                icon: const Icon(Icons.refresh),
                label: const Text('Réessayer'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            children: [
              // === HEADER PROFIL ===
              _buildProfileHeader(),

              const SizedBox(height: 20),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    // === STATISTIQUES ===
                    _buildStatsSection(),

                    const SizedBox(height: 24),

                    // === INFORMATIONS PERSONNELLES ===
                    _buildPersonalInfoSection(),

                    const SizedBox(height: 24),

                    // === PARAMÈTRES DE COMPTE ===
                    _buildAccountSettingsSection(),

                    const SizedBox(height: 24),

                    // === NOTIFICATIONS ===
                    _buildNotificationsSection(),

                    const SizedBox(height: 24),

                    // === À PROPOS ===
                    _buildAboutSection(),

                    const SizedBox(height: 24),

                    // === BOUTON DÉCONNEXION ===
                    _buildLogoutButton(),

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

  /// === WIDGETS PRINCIPAUX ===

  /// 1. HEADER PROFIL
  Widget _buildProfileHeader() {
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
        children: [
          // Avatar
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 4),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 10),
              ],
            ),
            child: const CircleAvatar(
              radius: 50,
              backgroundColor: Colors.white,
              child: Icon(Icons.person, size: 60, color: Color(0xFF667eea)),
            ),
          ),
          const SizedBox(height: 16),
          // Nom
          Text(
            userName,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          // Rôle
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withOpacity(0.3)),
            ),
            child: Text(
              userRole,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Score de compte
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.star, color: Colors.amber[300], size: 20),
              const SizedBox(width: 6),
              Text(
                '$accountScore/5',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 2. SECTION STATISTIQUES
  Widget _buildStatsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Statistiques'),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            _buildStatCard(
              icon: Icons.book,
              value: totalBorrows.toString(),
              label: 'Emprunts totaux',
              color: const Color(0xFF667eea),
            ),
            _buildStatCard(
              icon: Icons.bookmark,
              value: currentBorrows.toString(),
              label: 'En cours',
              color: Colors.orange,
            ),
            _buildStatCard(
              icon: Icons.archive,
              value: totalReservations.toString(),
              label: 'Réservations',
              color: Colors.purple,
            ),
            _buildStatCard(
              icon: Icons.rate_review,
              value: totalReviews.toString(),
              label: 'Avis donnés',
              color: Colors.green,
            ),
          ],
        ),
      ],
    );
  }

  /// 3. SECTION INFORMATIONS PERSONNELLES
  Widget _buildPersonalInfoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildSectionTitle('Informations Personnelles'),
            GestureDetector(
              onTap: () {
                setState(() {
                  isEditing = !isEditing;
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF667eea).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: const Color(0xFF667eea).withOpacity(0.3),
                  ),
                ),
                child: Text(
                  isEditing ? 'Annuler' : 'Modifier',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF667eea),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Nom
        _buildInfoField(
          icon: Icons.person,
          label: 'Nom complet',
          value: userName,
          controller: nameController,
          isEditing: isEditing,
        ),
        const SizedBox(height: 12),
        // Email
        _buildInfoField(
          icon: Icons.email,
          label: 'Email',
          value: userEmail,
          controller: emailController,
          isEditing: isEditing,
        ),
        const SizedBox(height: 12),
        // Téléphone
        _buildInfoField(
          icon: Icons.phone,
          label: 'Téléphone',
          value: userPhone,
          controller: phoneController,
          isEditing: isEditing,
        ),
        const SizedBox(height: 12),
        // Adresse
        _buildInfoField(
          icon: Icons.location_on,
          label: 'Adresse',
          value: userAddress,
          controller: addressController,
          isEditing: isEditing,
          maxLines: 2,
        ),
        const SizedBox(height: 12),
        // ID Membre
        _buildInfoField(
          icon: Icons.card_membership,
          label: 'Numéro Adhérent',
          value: memberId,
          controller: TextEditingController(text: memberId),
          isEditing: false,
        ),
        const SizedBox(height: 12),
        // Date d'adhésion
        _buildInfoField(
          icon: Icons.calendar_today,
          label: 'Date d\'adhésion',
          value: joinDate,
          controller: TextEditingController(text: joinDate),
          isEditing: false,
        ),
        if (isEditing) ...[const SizedBox(height: 16), _buildSaveButton()],
      ],
    );
  }

  /// 4. SECTION PARAMÈTRES DE COMPTE
  Widget _buildAccountSettingsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Paramètres de Compte'),
        const SizedBox(height: 12),
        // Changer mot de passe
        GestureDetector(
          onTap: () => _showChangePasswordDialog(),
          child: _buildSettingsTile(
            icon: Icons.lock,
            title: 'Changer le mot de passe',
            subtitle: 'Modifiez votre mot de passe de sécurité',
            trailing: Icons.arrow_forward_ios,
          ),
        ),
        const SizedBox(height: 12),
        // Préférences de compte
        _buildSettingsTile(
          icon: Icons.tune,
          title: 'Préférences',
          subtitle: 'Langue, thème, format de date',
          trailing: Icons.arrow_forward_ios,
        ),
        const SizedBox(height: 12),
        // Confidentialité
        _buildSettingsTile(
          icon: Icons.privacy_tip,
          title: 'Confidentialité et sécurité',
          subtitle: 'Gérez vos données personnelles',
          trailing: Icons.arrow_forward_ios,
        ),
        const SizedBox(height: 12),
        // Statistiques de compte
        _buildSettingsTile(
          icon: Icons.analytics,
          title: 'Activité et historique',
          subtitle: 'Consultez votre historique d\'emprunts',
          trailing: Icons.arrow_forward_ios,
        ),
      ],
    );
  }

  /// 5. SECTION NOTIFICATIONS
  Widget _buildNotificationsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Notifications'),
        const SizedBox(height: 12),
        // Email
        _buildNotificationToggle(
          icon: Icons.mail,
          title: 'Notifications par Email',
          subtitle: 'Recevez des mises à jour par email',
          value: emailNotifications,
          onChanged: (value) {
            setState(() {
              emailNotifications = value;
            });
          },
        ),
        const SizedBox(height: 12),
        // Push
        _buildNotificationToggle(
          icon: Icons.notifications,
          title: 'Notifications Push',
          subtitle: 'Recevez des alertes instantanées',
          value: pushNotifications,
          onChanged: (value) {
            setState(() {
              pushNotifications = value;
            });
          },
        ),
        const SizedBox(height: 12),
        // Rappels
        _buildNotificationToggle(
          icon: Icons.alarm,
          title: 'Rappels de Retour',
          subtitle: 'Rappels avant la date de retour',
          value: reminderNotifications,
          onChanged: (value) {
            setState(() {
              reminderNotifications = value;
            });
          },
        ),
      ],
    );
  }

  /// 6. SECTION À PROPOS
  Widget _buildAboutSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('À Propos'),
        const SizedBox(height: 12),
        _buildSettingsTile(
          icon: Icons.info,
          title: 'À propos de l\'application',
          subtitle: 'Version 1.0.0 • Build 2025',
          trailing: Icons.arrow_forward_ios,
        ),
        const SizedBox(height: 12),
        _buildSettingsTile(
          icon: Icons.policy,
          title: 'Conditions d\'utilisation',
          subtitle: 'Lisez nos conditions',
          trailing: Icons.arrow_forward_ios,
        ),
        const SizedBox(height: 12),
        _buildSettingsTile(
          icon: Icons.security,
          title: 'Politique de confidentialité',
          subtitle: 'Protégez vos données',
          trailing: Icons.arrow_forward_ios,
        ),
        const SizedBox(height: 12),
        _buildSettingsTile(
          icon: Icons.contact_support,
          title: 'Contactez le support',
          subtitle: 'support@libratech.com',
          trailing: Icons.arrow_forward_ios,
        ),
      ],
    );
  }

  /// 7. BOUTON DÉCONNEXION
  Widget _buildLogoutButton() {
    return GestureDetector(
      onTap: () => _showLogoutDialog(),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: Colors.red[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.red[200]!),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.logout, color: Colors.red[700], size: 20),
            const SizedBox(width: 8),
            Text(
              'Déconnexion',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.red[700],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// === WIDGETS AUXILIAIRES ===

  /// Titre de section
  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 16,
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
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.grey[300]!.withOpacity(0.5), blurRadius: 8),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF333333),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  /// Champ d'information
  Widget _buildInfoField({
    required IconData icon,
    required String label,
    required String value,
    required TextEditingController controller,
    required bool isEditing,
    int maxLines = 1,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isEditing ? const Color(0xFF667eea) : Colors.grey[200]!,
          width: isEditing ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(color: Colors.grey[300]!.withOpacity(0.5), blurRadius: 8),
        ],
      ),
      child: Row(
        crossAxisAlignment: maxLines > 1
            ? CrossAxisAlignment.start
            : CrossAxisAlignment.center,
        children: [
          Icon(icon, color: const Color(0xFF667eea), size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 6),
                if (isEditing &&
                    ![
                      'card_membership',
                      'calendar_today',
                    ].contains(icon.toString()))
                  TextField(
                    controller: controller,
                    maxLines: maxLines,
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                      hintText: value,
                    ),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF333333),
                    ),
                  )
                else
                  Text(
                    value,
                    maxLines: maxLines,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF333333),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Tuile de paramètres
  Widget _buildSettingsTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required IconData trailing,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.grey[300]!.withOpacity(0.5), blurRadius: 8),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF667eea).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: const Color(0xFF667eea), size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF333333),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          Icon(trailing, color: Colors.grey[400], size: 18),
        ],
      ),
    );
  }

  /// Toggle de notification
  Widget _buildNotificationToggle({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required Function(bool) onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.grey[300]!.withOpacity(0.5), blurRadius: 8),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF667eea).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: const Color(0xFF667eea), size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF333333),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: const Color(0xFF667eea),
          ),
        ],
      ),
    );
  }

  /// Bouton Enregistrer
  /// Bouton Enregistrer
Widget _buildSaveButton() {
  return GestureDetector(
    onTap: () => _updateUserProfile(),
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF667eea), Color(0xFF764ba2)],
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Text(
        'Enregistrer les modifications',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    ),
  );
}
/// Mettre à jour le profil utilisateur sur le backend
Future<void> _updateUserProfile() async {
  try {
    setState(() {
      isLoading = true;
    });

    // Récupérer l'ID utilisateur (déjà stocké dans memberId)
    int userId = int.tryParse(memberId) ?? 0;
    if (userId == 0) {
      throw Exception('ID utilisateur invalide');
    }

    // Préparer les données de mise à jour
    final Map<String, dynamic> updateData = {
      'username': nameController.text.trim(),
      'email': emailController.text.trim(),
      'phone': phoneController.text.trim(),
      'address': addressController.text.trim(),
    };

    // Nettoyer les champs vides
    updateData.removeWhere((key, value) => value == '');

    print('📤 Update payload: $updateData');
    
    final response = await http.patch(
      Uri.parse('https://libratech-backend.onrender.com/api/users/$userId/'),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        // Ajoutez le token d'authentification si nécessaire
        // 'Authorization': 'Bearer $token',
      },
      body: jsonEncode(updateData),
    );

    if (mounted) {
      print('🔍 Update - Status: ${response.statusCode}');
      print('🔍 Update - Body: ${response.body}');
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        // Mettre à jour l'état local
        setState(() {
          userName = nameController.text;
          userEmail = emailController.text;
          userPhone = phoneController.text;
          userAddress = addressController.text;
          isEditing = false;
          isLoading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profil mis à jour avec succès ✓'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        final errorBody = jsonDecode(response.body);
        String errorMessage = 'Erreur lors de la mise à jour';
        
        if (errorBody is Map<String, dynamic>) {
          if (errorBody.containsKey('detail')) {
            errorMessage = errorBody['detail'];
          } else if (errorBody.containsKey('message')) {
            errorMessage = errorBody['message'];
          } else {
            // Afficher les erreurs de validation
            errorMessage = '';
            errorBody.forEach((key, value) {
              if (value is List) {
                errorMessage += '${key}: ${value.join(", ")}\n';
              }
            });
          }
        }
        
        setState(() {
          isLoading = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  } catch (e) {
    if (mounted) {
      setState(() {
        isLoading = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
    print('❌ Update error: $e');
  }
}
  /// === DIALOGS ===

  /// Dialog Changer mot de passe
 /// Dialog Changer mot de passe
void _showChangePasswordDialog() {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Changer le mot de passe'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: passwordController,
              obscureText: !showPassword,
              decoration: InputDecoration(
                labelText: 'Mot de passe actuel',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                prefixIcon: const Icon(Icons.lock),
                suffixIcon: GestureDetector(
                  onTap: () {
                    setState(() {
                      showPassword = !showPassword;
                    });
                  },
                  child: Icon(
                    showPassword ? Icons.visibility : Icons.visibility_off,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: newPasswordController,
              obscureText: !showPassword,
              decoration: InputDecoration(
                labelText: 'Nouveau mot de passe',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                prefixIcon: const Icon(Icons.lock),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annuler'),
        ),
        TextButton(
          onPressed: () => _changePassword(),
          child: const Text(
            'Changer',
            style: TextStyle(color: Color(0xFF667eea)),
          ),
        ),
      ],
    ),
  );
}

/// Changer le mot de passe sur le backend
Future<void> _changePassword() async {
  try {
    if (passwordController.text.isEmpty || newPasswordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez remplir tous les champs'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    int userId = int.tryParse(memberId) ?? 0;
    if (userId == 0) {
      throw Exception('ID utilisateur invalide');
    }

    final Map<String, dynamic> passwordData = {
      'current_password': passwordController.text.trim(),
      'new_password': newPasswordController.text.trim(),
    };

    final response = await http.post(
      Uri.parse('https://libratech-backend.onrender.com/api/users/$userId/change-password/'),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: jsonEncode(passwordData),
    );

    if (mounted) {
      if (response.statusCode == 200 || response.statusCode == 201) {
        Navigator.pop(context);
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Mot de passe modifié avec succès ✓'),
            backgroundColor: Colors.green,
          ),
        );
        
        passwordController.clear();
        newPasswordController.clear();
      } else {
        final errorBody = jsonDecode(response.body);
        String errorMessage = 'Erreur lors du changement de mot de passe';
        
        if (errorBody is Map<String, dynamic>) {
          if (errorBody.containsKey('detail')) {
            errorMessage = errorBody['detail'];
          } else if (errorBody.containsKey('current_password')) {
            errorMessage = 'Mot de passe actuel incorrect';
          }
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Erreur: $e'),
        backgroundColor: Colors.red,
      ),
    );
    print('❌ Password change error: $e');
  }
}

  /// Dialog Déconnexion
  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Déconnexion'),
        content: const Text('Êtes-vous sûr de vouloir vous déconnecter ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const LoginScreen()),
              );
            },
            child: const Text(
              'Déconnexion',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }
}