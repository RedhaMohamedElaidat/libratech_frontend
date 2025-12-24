import 'dart:convert' show jsonDecode;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:libratech/Sign_up/signup.dart';
import 'package:libratech/main.dart';



class User {
  final String email;
  final String password;
  final String name;

  User({required this.email, required this.password, required this.name});
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // === TABLEAU MOCK D'UTILISATEURS ===
  final List<User> users = [
    User(email: 'alice@example.com', password: '123456', name: 'Alice'),
    User(email: 'bob@example.com', password: 'abcdef', name: 'Bob'),
    User(email: 'carol@example.com', password: 'password', name: 'Carol'),
  ];

  // === CONTROLEURS ===
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  // === ÉTAT ===
  bool showPassword = false;
  bool isLoading = false;
  bool rememberMe = false;
  String? generalError;
  String? emailError;
  String? passwordError;
@override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  // === VALIDATION EMAIL ===
  bool _isValidEmail(String email) {
    return RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    ).hasMatch(email);
  }

  bool _validateForm() {
    setState(() {
      generalError = null;
    });

    if (emailController.text.isEmpty || !_isValidEmail(emailController.text)) {
      setState(() {
        generalError = 'Email invalide';
      });
      return false;
    }
    if (passwordController.text.isEmpty || passwordController.text.length < 6) {
      setState(() {
        generalError = 'Mot de passe invalide';
      });
      return false;
    }
    return true;
  }

  // === LOGIN AVEC API ===
  Future<void> _handleLogin() async {
    if (!_validateForm()) return;

    setState(() {
      isLoading = true;
      generalError = null;
    });

    try {
      final response = await http.get(Uri.parse('https://libratech-backend.onrender.com/api/users/'));

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        final List users = jsonData['results'] ?? [];

        final inputEmail = emailController.text.trim().toLowerCase();

        // Chercher l'utilisateur par email
        final matchedUser = users.firstWhere(
          (user) => user['email'].toString().toLowerCase() == inputEmail,
          orElse: () => null,
        );

        if (matchedUser == null) {
          setState(() {
            generalError = 'Email non trouvé';
            isLoading = false;
          });
          return;
        }

        // Pour test local, mot de passe fixe
        if (passwordController.text != 'password123') {
          setState(() {
            generalError = 'Mot de passe incorrect';
            isLoading = false;
          });
          return;
        }

        // Construire le fullName depuis first_name + last_name
        String fullName = '';
        if (matchedUser['first_name'] != null && matchedUser['first_name'].isNotEmpty) {
          fullName += matchedUser['first_name'];
        }
        if (matchedUser['last_name'] != null && matchedUser['last_name'].isNotEmpty) {
          if (fullName.isNotEmpty) fullName += ' ';
          fullName += matchedUser['last_name'];
        }
        if (fullName.isEmpty) fullName = matchedUser['username'];

        // Login réussi → navigation vers HomeScreen
        if (!mounted) return;
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (context) => HomeScreen(
              userName: matchedUser['username'],
              userEmail: matchedUser['email'],
              fullName: fullName, 
              userId: matchedUser['id'],
              
            ),
          ),
          (route) => false,
        );

      } else {
        setState(() {
          generalError = 'Erreur serveur: ${response.statusCode}';
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        generalError = 'Erreur de connexion: $e';
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),
                _buildHeader(),
                const SizedBox(height: 40),
                if (generalError != null) ...[
                  _buildErrorBanner(),
                  const SizedBox(height: 16),
                ],
                _buildEmailField(),
                const SizedBox(height: 16),
                _buildPasswordField(),
                const SizedBox(height: 12),
                _buildRememberAndForgot(),
                const SizedBox(height: 24),
                _buildLoginButton(),
                const SizedBox(height: 20),
                _buildDivider(),
                const SizedBox(height: 20),
                _buildSocialLogin(),
                const SizedBox(height: 24),
                _buildSignupLink(),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // === WIDGETS ===
  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF667eea).withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF667eea).withOpacity(0.3)),
          ),
          child: const Icon(
            Icons.library_books,
            color: Color(0xFF667eea),
            size: 32,
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Bienvenue',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Color(0xFF333333),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Connectez-vous à votre compte LibraTech',
          style: TextStyle(fontSize: 14, color: Colors.grey[600]),
        ),
      ],
    );
  }

  Widget _buildErrorBanner() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red[50],
        border: Border.all(color: Colors.red[200]!),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: Colors.red[700], size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              generalError ?? '',
              style: TextStyle(
                fontSize: 12,
                color: Colors.red[700],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmailField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Email',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Color(0xFF333333),
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: emailController,
          keyboardType: TextInputType.emailAddress,
          decoration: InputDecoration(
            hintText: 'exemple@email.com',
            hintStyle: TextStyle(color: Colors.grey[400]),
            prefixIcon: const Icon(Icons.email, color: Color(0xFF667eea)),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFF667eea), width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Colors.red, width: 2),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Colors.red, width: 2),
            ),
            filled: true,
            fillColor: Colors.white,
            errorText: emailError,
          ),
          onChanged: (value) {
            if (emailError != null) {
              setState(() {
                emailError = null;
              });
            }
          },
        ),
      ],
    );
  }

  Widget _buildPasswordField() { /* identique à ton code précédent */ 
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Mot de passe',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Color(0xFF333333),
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: passwordController,
          obscureText: !showPassword,
          decoration: InputDecoration(
            hintText: '••••••••',
            hintStyle: TextStyle(color: Colors.grey[400]),
            prefixIcon: const Icon(Icons.lock, color: Color(0xFF667eea)),
            suffixIcon: GestureDetector(
              onTap: () {
                setState(() {
                  showPassword = !showPassword;
                });
              },
              child: Icon(
                showPassword ? Icons.visibility : Icons.visibility_off,
                color: Colors.grey[600],
              ),
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFF667eea), width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Colors.red, width: 2),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Colors.red, width: 2),
            ),
            filled: true,
            fillColor: Colors.white,
            errorText: passwordError,
          ),
          onChanged: (value) {
            if (passwordError != null) {
              setState(() {
                passwordError = null;
              });
            }
          },
        ),
      ],
    );
  }




  /// 5. REMEMBER ME + FORGOT PASSWORD
  Widget _buildRememberAndForgot() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Remember Me
        GestureDetector(
          onTap: () {
            setState(() {
              rememberMe = !rememberMe;
            });
          },
          child: Row(
            children: [
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: rememberMe
                        ? const Color(0xFF667eea)
                        : Colors.grey[400]!,
                  ),
                  borderRadius: BorderRadius.circular(4),
                  color: rememberMe
                      ? const Color(0xFF667eea)
                      : Colors.transparent,
                ),
                child: rememberMe
                    ? const Icon(Icons.check, size: 14, color: Colors.white)
                    : null,
              ),
              const SizedBox(width: 8),
              Text(
                'Se souvenir de moi',
                style: TextStyle(fontSize: 12, color: Colors.grey[700]),
              ),
            ],
          ),
        ),
        // Forgot Password
        GestureDetector(
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Redirection vers la récupération du MDP'),
              ),
            );
          },
          child: const Text(
            'Mot de passe oublié?',
            style: TextStyle(
              fontSize: 12,
              color: Color(0xFF667eea),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  /// 6. BOUTON CONNEXION
  Widget _buildLoginButton() {
    return GestureDetector(
      onTap: isLoading ? null : _handleLogin,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF667eea), Color(0xFF764ba2)],
          ),
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF667eea).withOpacity(0.3),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: isLoading
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  strokeWidth: 2,
                ),
              )
            : const Text(
                'Connexion',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
      ),
    );
  }

  /// 7. DIVIDER
  Widget _buildDivider() {
    return Row(
      children: [
        Expanded(child: Divider(color: Colors.grey[300])),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            'Ou continuer avec',
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
        ),
        Expanded(child: Divider(color: Colors.grey[300])),
      ],
    );
  }

  /// 8. CONNEXION SOCIALE
  Widget _buildSocialLogin() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildSocialButton(icon: '🔵', label: 'Facebook', onTap: () {}),
        const SizedBox(width: 12),
        _buildSocialButton(icon: '🔴', label: 'Google', onTap: () {}),
        const SizedBox(width: 12),
        _buildSocialButton(icon: '⬛', label: 'Apple', onTap: () {}),
      ],
    );
  }

  /// Bouton social
  Widget _buildSocialButton({
    required String icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[300]!),
          borderRadius: BorderRadius.circular(10),
          color: Colors.white,
        ),
        child: Text(icon, style: const TextStyle(fontSize: 20)),
      ),
    );
  }

  /// 9. LIEN INSCRIPTION
  Widget _buildSignupLink() {
    return Center(
      child: RichText(
        text: TextSpan(
          children: [
            TextSpan(
              text: 'Pas encore de compte? ',
              style: TextStyle(fontSize: 13, color: Colors.grey[700]),
            ),
            TextSpan(
              text: 'S\'inscrire',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: Color(0xFF667eea),
              ),
              recognizer: TapGestureRecognizer()
                ..onTap = () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const SignupScreen(),
                    ),
                  );
                },
            ),
          ],
        ),
      ),
    );
  }
}