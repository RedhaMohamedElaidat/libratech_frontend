import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class BooksListScreen extends StatefulWidget {
  const BooksListScreen({Key? key}) : super(key: key);

  @override
  State<BooksListScreen> createState() => _BooksListScreenState();
}

class _BooksListScreenState extends State<BooksListScreen> {
  // === API CONFIGURATION ===
  final String apiUrl = 'https://libratech-backend.onrender.com/api/books/';
  final String baseUrl = 'https://libratech-backend.onrender.com';

  // === DONNÉES  DES LIVRES DANS LA BDD===
  String searchQuery = '';
  String selectedCategory = 'Tous';
  bool isGridView = false;
  bool isLoading = true;
  String? errorMessage;

  List<String> categories = ['Tous'];
  List<Map<String, dynamic>> allBooks = [];

  @override
  void initState() {
    super.initState();
    _fetchBooks();
  }

  // === API CALLS ===

  /// Récupérer les livres depuis le backend 
  Future<void> _fetchBooks() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final response = await http.get(Uri.parse(apiUrl));

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);

        // Gérer différentes structures de réponse
        List<dynamic> booksData =
            jsonData is List ? jsonData : jsonData['results'] ?? [];

        setState(() {
          allBooks = List<Map<String, dynamic>>.from(
  booksData.map((book) => {
    'id': book['id'] ?? 0,
    'title': book['title'] ?? 'Sans titre',
    'author': book['author'] ?? 'Auteur inconnu',
    'category': book['category'] ?? 'Autre',
    'rating': (book['rating'] ?? 0).toDouble(),
    'reviews': book['reviews_count'] ?? 0,

    //  LA CORRECTION CLÉ
    'available': (book['available_copies'] ?? 0) > 0,
    'copies': book['available_copies'] ?? 0,

    'imageIcon': '📖',
    'description': book['description'] ?? '',
    'pages': book['pages'] ?? 0,
    'year': book['publication_year'] ?? 0,
    'isbn': book['isbn'] ?? '',
  }),
);


          _updateCategories();
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

  /// Mettre à jour les catégories depuis les livres 
  void _updateCategories() {
    Set<String> uniqueCategories = {'Tous'};
    for (var book in allBooks) {
      uniqueCategories.add(book['category']);
    }
    categories = uniqueCategories.toList();
  }

  /// Réserver un livre mais il faut verifier aussi
  Future<void> _reserveBook(Map<String, dynamic> book, [BuildContext? callerContext]) async {
    try {
      final response = await http.post(
        Uri.parse('$apiUrl${book['id']}/reserve/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'user_id': 1}), // À adapter selon votre système d'auth
      );

      if (mounted) {
        final usedContext = callerContext ?? context;
        if (response.statusCode == 200 || response.statusCode == 201) {
          ScaffoldMessenger.of(usedContext).showSnackBar(
            SnackBar(
              content: Text('${book['title']} réservé avec succès ✓'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );
          _fetchBooks(); // Rafraîchir la liste chaque fois 
        } else {
          ScaffoldMessenger.of(usedContext).showSnackBar(
            SnackBar(
              content: const Text('Erreur lors de la réservation'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      final usedContext = callerContext ?? context;
      ScaffoldMessenger.of(usedContext).showSnackBar(
        SnackBar(
          content: Text('Erreur: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  /// Emprunter un livre mais il faut verifier
  Future<void> _borrowBook(Map<String, dynamic> book, [BuildContext? callerContext]) async {
    try {
      final response = await http.post(
        Uri.parse('$apiUrl${book['id']}/borrow/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'user_id': 1}),
      );

      if (mounted) {
        final usedContext = callerContext ?? context;
        if (response.statusCode == 200 || response.statusCode == 201) {
          ScaffoldMessenger.of(usedContext).showSnackBar(
            SnackBar(
              content: Text('${book['title']} emprunté avec succès ✓'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );
          _fetchBooks();
        } else {
          ScaffoldMessenger.of(usedContext).showSnackBar(
            SnackBar(
              content: const Text('Erreur lors de l\'emprunt'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      final usedContext = callerContext ?? context;
      ScaffoldMessenger.of(usedContext).showSnackBar(
        SnackBar(
          content: Text('Erreur: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  /// Afficher un message de succès
  /*void _showSuccessSnackBar(String message) {
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
*/
  // Getter pour les livres filtrés
  List<Map<String, dynamic>> get filteredBooks {
    List<Map<String, dynamic>> filtered = allBooks;

    if (selectedCategory != 'Tous') {
      filtered = filtered
          .where((book) => book['category'] == selectedCategory)
          .toList();
    }

    if (searchQuery.isNotEmpty) {
      filtered = filtered
          .where((book) =>
              book['title']
                  .toLowerCase()
                  .contains(searchQuery.toLowerCase()) ||
              book['author']
                  .toLowerCase()
                  .contains(searchQuery.toLowerCase()))
          .toList();
    }

    return filtered;
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
                        _buildHeader(),
                        const SizedBox(height: 16),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: _buildSearchBar(),
                        ),
                        const SizedBox(height: 16),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: _buildCategoryFilter(),
                        ),
                        const SizedBox(height: 16),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: _buildViewToggle(),
                        ),
                        const SizedBox(height: 16),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: _buildResultsCount(),
                        ),
                        const SizedBox(height: 12),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: isGridView
                              ? _buildBooksGrid()
                              : _buildBooksList(),
                        ),
                        const SizedBox(height: 30),
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
          const Text('Chargement des livres...'),
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
            onPressed: _fetchBooks,
            icon: const Icon(Icons.refresh),
            label: const Text('Réessayer'),
          ),
        ],
      ),
    );
  }

  // === WIDGETS ===

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
                    'Catalogue',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Découvrez nos Livres',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              GestureDetector(
                onTap: _fetchBooks,
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white.withOpacity(0.3)),
                  ),
                  child: const Icon(
                    Icons.library_books,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Total: ${allBooks.length} livres • ${allBooks.where((b) => b['available']).length} disponibles',
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return TextField(
      onChanged: (value) {
        setState(() {
          searchQuery = value;
        });
      },
      decoration: InputDecoration(
        hintText: 'Rechercher par titre ou auteur...',
        hintStyle: TextStyle(color: Colors.grey[500]),
        prefixIcon: const Icon(Icons.search, color: Color(0xFF667eea)),
        suffixIcon: searchQuery.isNotEmpty
            ? GestureDetector(
                onTap: () {
                  setState(() {
                    searchQuery = '';
                  });
                },
                child: const Icon(Icons.close, color: Color(0xFF667eea)),
              )
            : null,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF667eea), width: 2),
        ),
        filled: true,
        fillColor: Colors.white,
      ),
    );
  }

  Widget _buildCategoryFilter() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: categories
            .map(
              (category) => GestureDetector(
                onTap: () {
                  setState(() {
                    selectedCategory = category;
                  });
                },
                child: Container(
                  margin: const EdgeInsets.only(right: 10),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: selectedCategory == category
                        ? const Color(0xFF667eea)
                        : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: selectedCategory == category
                          ? const Color(0xFF667eea)
                          : Colors.grey[300]!,
                    ),
                    boxShadow: selectedCategory == category
                        ? [
                            BoxShadow(
                              color: const Color(0xFF667eea).withOpacity(0.3),
                              blurRadius: 8,
                            ),
                          ]
                        : [],
                  ),
                  child: Text(
                    category,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: selectedCategory == category
                          ? Colors.white
                          : Colors.grey[700],
                    ),
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _buildViewToggle() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          'Affichage',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Color(0xFF333333),
          ),
        ),
        Row(
          children: [
            GestureDetector(
              onTap: () {
                setState(() {
                  isGridView = false;
                });
              },
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: !isGridView
                      ? const Color(0xFF667eea)
                      : Colors.grey[200],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.list,
                  color: !isGridView ? Colors.white : Colors.grey[600],
                  size: 20,
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () {
                setState(() {
                  isGridView = true;
                });
              },
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color:
                      isGridView ? const Color(0xFF667eea) : Colors.grey[200],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.grid_3x3,
                  color: isGridView ? Colors.white : Colors.grey[600],
                  size: 20,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildResultsCount() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          '${filteredBooks.length} résultat(s)',
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Color(0xFF667eea),
          ),
        ),
        GestureDetector(
          onTap: () {
            setState(() {
              filteredBooks.sort((a, b) => b['rating'].compareTo(a['rating']));
            });
          },
          child: Row(
            children: [
              Icon(Icons.sort, color: Colors.grey[600], size: 18),
              const SizedBox(width: 6),
              Text(
                'Trier',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBooksList() {
    if (filteredBooks.isEmpty) {
      return _buildEmptyState();
    }

    return Column(
      children: filteredBooks.map((book) => _buildBookCard(book)).toList(),
    );
  }

  Widget _buildBooksGrid() {
    if (filteredBooks.isEmpty) {
      return _buildEmptyState();
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.75,
      ),
      itemCount: filteredBooks.length,
      itemBuilder: (context, index) {
        return _buildBookGridCard(filteredBooks[index]);
      },
    );
  }

  Widget _buildBookCard(Map<String, dynamic> book) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 70,
            height: 100,
            decoration: BoxDecoration(
              color: const Color(0xFF667eea).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(book['imageIcon'], style: const TextStyle(fontSize: 40)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  book['title'],
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
                  book['author'],
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(Icons.star, size: 14, color: Colors.amber[700]),
                    const SizedBox(width: 4),
                    Text(
                      '${book['rating']} (${book['reviews']} avis)',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF333333),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF667eea).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        book['category'],
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF667eea),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (book['available'])
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.green[50],
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '${book['copies']} cop.',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: Colors.green[700],
                          ),
                        ),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.red[50],
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'Indisponible',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: Colors.red,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => _handleBookAction(book),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: book['available']
                    ? const Color(0xFF667eea).withOpacity(0.1)
                    : Colors.grey[200],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                book['available'] ? Icons.add_circle : Icons.bookmark_border,
                color: book['available']
                    ? const Color(0xFF667eea)
                    : Colors.grey[400],
                size: 24,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBookGridCard(Map<String, dynamic> book) {
    return GestureDetector(
      onTap: () => _handleBookAction(book),
      child: Container(
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 140,
              decoration: BoxDecoration(
                color: const Color(0xFF667eea).withOpacity(0.1),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
              ),
              child: Center(
                child: Text(book['imageIcon'],
                    style: const TextStyle(fontSize: 50)),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      book['title'],
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF333333),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      book['author'],
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(Icons.star, size: 12, color: Colors.amber[700]),
                        const SizedBox(width: 2),
                        Text(
                          '${book['rating']}',
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      decoration: BoxDecoration(
                        color: book['available']
                            ? const Color(0xFF667eea).withOpacity(0.1)
                            : Colors.grey[200],
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        book['available'] ? 'Ajouter' : 'Non dispo',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: book['available']
                              ? const Color(0xFF667eea)
                              : Colors.grey[600],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Column(
          children: [
            Icon(
              Icons.library_books_outlined,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'Aucun livre trouvé',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Essayez une autre recherche',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleBookAction(Map<String, dynamic> book) {
    if (!book['available']) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Livre indisponible'),
          content: Text('Voulez-vous réserver "${book['title']}" ?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _reserveBook(book);
              },
              child: const Text('Réserver'),
            ),
          ],
        ),
      );
    } else {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(book['title']),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildDialogRow('Auteur', book['author']),
                _buildDialogRow('Catégorie', book['category']),
                _buildDialogRow('Pages', '${book['pages']}'),
                _buildDialogRow('Année', '${book['year']}'),
                _buildDialogRow('ISBN', book['isbn']),
                _buildDialogRow('Rating', '${book['rating']} ⭐'),
                _buildDialogRow('Disponibilité', '${book['copies']} cop.'),
                const SizedBox(height: 12),
                Text(
                  book['description'],
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Fermer'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _borrowBook(book);
              },
              child: const Text('Emprunter'),
            ),
          ],
        ),
      );
    }
  }

  Widget _buildDialogRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          ),
          Text(
            value,
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }
}
