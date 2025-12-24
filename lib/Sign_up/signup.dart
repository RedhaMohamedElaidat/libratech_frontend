import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:libratech/login/login.dart' show LoginScreen;

class SignupScreen extends StatefulWidget {
  const SignupScreen({Key? key}) : super(key: key);

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  // === API CONFIGURATION ===
  final String usersApiUrl = 'https://libratech-backend.onrender.com/api/users/';
  final String baseUrl = 'https://libratech-backend.onrender.com';

  // === CONTRÔLEURS DE TEXTE ===
  final TextEditingController nameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPasswordController =
      TextEditingController();

  // === ÉTAT DE L'APPLICATION ===
  bool showPassword = false;
  bool showConfirmPassword = false;
  bool acceptTerms = false;
  bool isLoading = false;

  // === MESSAGES D'ERREUR ===
  String? nameError;
  String? emailError;
  String? phoneError;
  String? passwordError;
  String? confirmPasswordError;
  String? termsError;
  String? generalError;

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    phoneController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  // === FONCTION : VALIDATION EMAIL ===
  bool _isValidEmail(String email) {
    return RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    ).hasMatch(email);
  }

  // === FONCTION : VALIDATION NOM ===
  bool _isValidName(String name) {
    return name.length >= 3;
  }

  // === FONCTION : VALIDATION TÉLÉPHONE ===
  bool _isValidPhone(String phone) {
    return phone.length >= 10;
  }

  // === FONCTION : VALIDATION MOT DE PASSE ===
  bool _isValidPassword(String password) {
    return password.length >= 6;
  }

  // === FONCTION : VALIDATION DU FORMULAIRE COMPLET ===
  bool _validateForm() {
    // Réinitialiser tous les erreurs
    setState(() {
      nameError = null;
      emailError = null;
      phoneError = null;
      passwordError = null;
      confirmPasswordError = null;
      termsError = null;
      generalError = null;
    });

    bool isValid = true;

    // === VALIDATION NOM ===
    if (nameController.text.isEmpty) {
      setState(() {
        nameError = 'Le nom est obligatoire';
      });
      isValid = false;
    } else if (!_isValidName(nameController.text)) {
      setState(() {
        nameError = 'Minimum 3 caractères';
      });
      isValid = false;
    }

    // === VALIDATION EMAIL ===
    if (emailController.text.isEmpty) {
      setState(() {
        emailError = 'L\'email est obligatoire';
      });
      isValid = false;
    } else if (!_isValidEmail(emailController.text)) {
      setState(() {
        emailError = 'Email invalide';
      });
      isValid = false;
    }

    // === VALIDATION TÉLÉPHONE ===
    if (phoneController.text.isEmpty) {
      setState(() {
        phoneError = 'Le téléphone est obligatoire';
      });
      isValid = false;
    } else if (!_isValidPhone(phoneController.text)) {
      setState(() {
        phoneError = 'Minimum 10 chiffres';
      });
      isValid = false;
    }

    // === VALIDATION MOT DE PASSE ===
    if (passwordController.text.isEmpty) {
      setState(() {
        passwordError = 'Le mot de passe est obligatoire';
      });
      isValid = false;
    } else if (!_isValidPassword(passwordController.text)) {
      setState(() {
        passwordError = 'Minimum 6 caractères';
      });
      isValid = false;
    }

    // === VALIDATION CONFIRMATION MOT DE PASSE ===
    if (confirmPasswordController.text.isEmpty) {
      setState(() {
        confirmPasswordError = 'Confirmez le mot de passe';
      });
      isValid = false;
    } else if (passwordController.text != confirmPasswordController.text) {
      setState(() {
        confirmPasswordError = 'Les mots de passe ne correspondent pas';
      });
      isValid = false;
    }

    // === VALIDATION CONDITIONS ===
    if (!acceptTerms) {
      setState(() {
        termsError = 'Acceptez les conditions d\'utilisation';
      });
      isValid = false;
    }

    return isValid;
  }

  // === FONCTION : GÉRER L'INSCRIPTION ===
  Future<void> _handleSignup() async {
    // Valider le formulaire
    if (!_validateForm()) {
      return;
    }

    setState(() {
      isLoading = true;
      generalError = null;
    });

    try {
      final response = await http.post(
        Uri.parse(usersApiUrl),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'username': emailController.text.trim().toLowerCase(),
          'full_name': nameController.text.trim(),
          'email': emailController.text.trim().toLowerCase(),
          'phone': phoneController.text.trim(),
          'password': passwordController.text,
          'password_confirm': confirmPasswordController.text,
          
        }),
      );

      if (mounted) {
        if (response.statusCode == 201 || response.statusCode == 200) {
          // Inscription réussie
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Inscription réussie ✓'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );

          // Attendre 1 seconde puis rediriger vers la connexion
          await Future.delayed(const Duration(seconds: 1));

          if (mounted) {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (context) => const LoginScreen()),
              (route) => false,
            );
          }
        } else if (response.statusCode == 400) {
          // Erreur de validation du backend
          final errorData = jsonDecode(response.body);
          String errorMsg = 'Erreur d\'inscription';

          if (errorData is Map) {
            if (errorData.containsKey('email')) {
              setState(() {
                emailError = errorData['email']?.join(', ') ?? 'Email invalide';
              });
            } else if (errorData.containsKey('phone')) {
              setState(() {
                phoneError =
                    errorData['phone']?.join(', ') ?? 'Téléphone invalide';
              });
            } else if (errorData.containsKey('password')) {
              setState(() {
                passwordError = errorData['password']?.join(', ') ??
                    'Mot de passe invalide';
              });
            } else if (errorData.containsKey('full_name')) {
              setState(() {
                nameError =
                    errorData['full_name']?.join(', ') ?? 'Nom invalide';
              });
            } else {
              errorMsg = errorData['detail'] ??
                  errorData.toString() ??
                  'Erreur d\'inscription';
            }
          }

          setState(() {
            generalError = errorMsg;
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorMsg),
              backgroundColor: Colors.red,
            ),
          );
        } else if (response.statusCode == 409) {
          // Conflit - utilisateur existe déjà
          setState(() {
            emailError = 'Cet email est déjà utilisé';
          });

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Cet email est déjà utilisé'),
              backgroundColor: Colors.red,
            ),
          );
        } else {
          // Autre erreur serveur
          setState(() {
            generalError =
                'Erreur serveur (${response.statusCode}). Veuillez réessayer.';
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  'Erreur: ${response.statusCode}. Veuillez réessayer.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          generalError = 'Erreur de connexion: ${e.toString()}';
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur de connexion: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
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
                const SizedBox(height: 12),

                // === SECTION HEADER ===
                _buildHeader(),

                const SizedBox(height: 30),

                // === MESSAGE D'ERREUR GÉNÉRAL ===
                if (generalError != null) ...[
                  _buildErrorBanner(),
                  const SizedBox(height: 16),
                ],

                // === CHAMP NOM COMPLET ===
                _buildNameField(),

                const SizedBox(height: 14),

                // === CHAMP EMAIL ===
                _buildEmailField(),

                const SizedBox(height: 14),

                // === CHAMP TÉLÉPHONE ===
                _buildPhoneField(),

                const SizedBox(height: 14),

                // === CHAMP MOT DE PASSE ===
                _buildPasswordField(),

                const SizedBox(height: 14),

                // === CHAMP CONFIRMER MOT DE PASSE ===
                _buildConfirmPasswordField(),

                const SizedBox(height: 16),

                // === CHECKBOX CONDITIONS D'UTILISATION ===
                _buildTermsCheckbox(),

                const SizedBox(height: 20),

                // === BOUTON INSCRIPTION ===
                _buildSignupButton(),

                const SizedBox(height: 16),

                // === LIEN VERS CONNEXION ===
                _buildLoginLink(),

                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// === WIDGET : HEADER ===
  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Logo/Icon LibraTech
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

        // Titre principal
        const Text(
          'Créer un compte',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Color(0xFF333333),
          ),
        ),
        const SizedBox(height: 8),

        // Sous-titre
        Text(
          'Rejoignez LibraTech et accédez à nos services',
          style: TextStyle(fontSize: 14, color: Colors.grey[600]),
        ),
      ],
    );
  }

  /// === WIDGET : BANNEAU D'ERREUR ===
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

  /// === WIDGET : CHAMP NOM ===
  Widget _buildNameField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Label
        const Text(
          'Nom complet',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Color(0xFF333333),
          ),
        ),
        const SizedBox(height: 8),

        // Champ texte
        TextField(
          controller: nameController,
          decoration: InputDecoration(
            hintText: 'Ahmed Mohamed',
            hintStyle: TextStyle(color: Colors.grey[400]),
            prefixIcon: const Icon(Icons.person, color: Color(0xFF667eea)),
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
            filled: true,
            fillColor: Colors.white,
            errorText: nameError,
          ),
          onChanged: (value) {
            if (nameError != null) {
              setState(() {
                nameError = null;
              });
            }
          },
        ),
      ],
    );
  }

  /// === WIDGET : CHAMP EMAIL ===
  Widget _buildEmailField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Label
        const Text(
          'Email',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Color(0xFF333333),
          ),
        ),
        const SizedBox(height: 8),

        // Champ texte
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

  /// === WIDGET : CHAMP TÉLÉPHONE ===
  Widget _buildPhoneField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Label
        const Text(
          'Téléphone',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Color(0xFF333333),
          ),
        ),
        const SizedBox(height: 8),

        // Champ texte
        TextField(
          controller: phoneController,
          keyboardType: TextInputType.phone,
          decoration: InputDecoration(
            hintText: '+213 698 123 456',
            hintStyle: TextStyle(color: Colors.grey[400]),
            prefixIcon: const Icon(Icons.phone, color: Color(0xFF667eea)),
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
            filled: true,
            fillColor: Colors.white,
            errorText: phoneError,
          ),
          onChanged: (value) {
            if (phoneError != null) {
              setState(() {
                phoneError = null;
              });
            }
          },
        ),
      ],
    );
  }

  /// === WIDGET : CHAMP MOT DE PASSE ===
  Widget _buildPasswordField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Label
        const Text(
          'Mot de passe',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Color(0xFF333333),
          ),
        ),
        const SizedBox(height: 8),

        // Champ texte avec toggle show/hide
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

  /// === WIDGET : CHAMP CONFIRMER MOT DE PASSE ===
  Widget _buildConfirmPasswordField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Label
        const Text(
          'Confirmer le mot de passe',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Color(0xFF333333),
          ),
        ),
        const SizedBox(height: 8),

        // Champ texte avec toggle show/hide
        TextField(
          controller: confirmPasswordController,
          obscureText: !showConfirmPassword,
          decoration: InputDecoration(
            hintText: '••••••••',
            hintStyle: TextStyle(color: Colors.grey[400]),
            prefixIcon: const Icon(Icons.lock, color: Color(0xFF667eea)),
            suffixIcon: GestureDetector(
              onTap: () {
                setState(() {
                  showConfirmPassword = !showConfirmPassword;
                });
              },
              child: Icon(
                showConfirmPassword ? Icons.visibility : Icons.visibility_off,
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
            filled: true,
            fillColor: Colors.white,
            errorText: confirmPasswordError,
          ),
          onChanged: (value) {
            if (confirmPasswordError != null) {
              setState(() {
                confirmPasswordError = null;
              });
            }
          },
        ),
      ],
    );
  }

  /// === WIDGET : CHECKBOX CONDITIONS D'UTILISATION ===
  Widget _buildTermsCheckbox() {
    return GestureDetector(
      onTap: () {
        setState(() {
          acceptTerms = !acceptTerms;
          if (acceptTerms) {
            termsError = null;
          }
        });
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Checkbox personnalisé
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: acceptTerms
                        ? const Color(0xFF667eea)
                        : Colors.grey[400]!,
                  ),
                  borderRadius: BorderRadius.circular(4),
                  color: acceptTerms
                      ? const Color(0xFF667eea)
                      : Colors.transparent,
                ),
                child: acceptTerms
                    ? const Icon(Icons.check, size: 14, color: Colors.white)
                    : null,
              ),
              const SizedBox(width: 10),

              // Texte des conditions
              Expanded(
                child: RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: 'J\'accepte les ',
                        style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                      ),
                      const TextSpan(
                        text: 'conditions d\'utilisation',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF667eea),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // Message d'erreur si non accepté
          if (termsError != null) ...[
            const SizedBox(height: 6),
            Text(
              termsError!,
              style: const TextStyle(fontSize: 12, color: Colors.red),
            ),
          ],
        ],
      ),
    );
  }

  /// === WIDGET : BOUTON INSCRIPTION ===
  Widget _buildSignupButton() {
    return GestureDetector(
      onTap: isLoading ? null : _handleSignup,
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
                'S\'inscrire',
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

  /// === WIDGET : LIEN VERS CONNEXION ===
  Widget _buildLoginLink() {
    return Center(
      child: RichText(
        text: TextSpan(
          children: [
            TextSpan(
              text: 'Vous avez déjà un compte? ',
              style: TextStyle(fontSize: 13, color: Colors.grey[700]),
            ),
            TextSpan(
              text: 'Connexion',
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
                      builder: (context) => const LoginScreen(),
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