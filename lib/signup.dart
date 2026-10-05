import 'package:flutter/material.dart';
import 'authentication.dart';
import 'home.dart';

class Signup extends StatelessWidget {
  const Signup({super.key});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.blue.shade900,
              Colors.blue.shade600,
              Colors.blue.shade300,
            ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
            child: Column(
              children: [
                SizedBox(height: size.height * 0.03),
                // Botão para voltar atrás
                Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
                // Ícone e Título
                const Icon(
                  Icons.person_add_alt_1_rounded,
                  size: 64,
                  color: Colors.white,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Criar Nova Conta',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Registe-se para começar a jogar',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                ),
                SizedBox(height: size.height * 0.03),

                // Cartão do Formulário
                Card(
                  elevation: 8,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Padding(
                    padding: EdgeInsets.all(24.0),
                    child: SignupForm(),
                  ),
                ),
                const SizedBox(height: 20),

                // Link para voltar ao Login
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'Já possui cadastro? ',
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: const Text(
                        'Faça o login',
                        style: TextStyle(
                          color: Colors.yellowAccent,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class SignupForm extends StatefulWidget {
  const SignupForm({super.key});

  @override
  State<SignupForm> createState() => _SignupFormState();
}

class _SignupFormState extends State<SignupForm> {
  final _formKey = GlobalKey<FormState>();
  final _passController = TextEditingController();

  String? email;
  String? password;
  bool _obscureText = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _passController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const Text(
            'Preencha os seus dados',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.blueGrey,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),

          // Email
          TextFormField(
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.email_outlined),
              labelText: 'Email',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16.0),
              ),
              filled: true,
              fillColor: Colors.grey.shade50,
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Por favor, introduza o email';
              }
              if (!value.contains('@')) {
                return 'Email inválido';
              }
              return null;
            },
            onSaved: (val) => email = val?.trim(),
          ),
          const SizedBox(height: 14),

          // Senha
          TextFormField(
            controller: _passController,
            decoration: InputDecoration(
              labelText: 'Senha',
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureText ? Icons.visibility_off : Icons.visibility,
                ),
                onPressed: () {
                  setState(() {
                    _obscureText = !_obscureText;
                  });
                },
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16.0),
              ),
              filled: true,
              fillColor: Colors.grey.shade50,
            ),
            obscureText: _obscureText,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Por favor, introduza uma senha';
              }
              if (value.length < 6) {
                return 'A senha deve ter pelo menos 6 caracteres';
              }
              return null;
            },
            onSaved: (val) => password = val,
          ),
          const SizedBox(height: 14),

          // Confirmar Senha
          TextFormField(
            decoration: InputDecoration(
              labelText: 'Confirme a senha',
              prefixIcon: const Icon(Icons.lock_reset_outlined),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16.0),
              ),
              filled: true,
              fillColor: Colors.grey.shade50,
            ),
            obscureText: true,
            validator: (value) {
              if (value != _passController.text) {
                return 'As senhas não coincidem';
              }
              return null;
            },
          ),
          const SizedBox(height: 24),

          // Botão Registar
          SizedBox(
            height: 50,
            child: ElevatedButton(
              onPressed: _isLoading
                  ? null
                  : () {
                      if (_formKey.currentState!.validate()) {
                        _formKey.currentState!.save();
                        setState(() => _isLoading = true);

                        AuthenticationHelper()
                            .signUp(email: email!, password: password!)
                            .then((result) {
                          if (!mounted) return;
                          setState(() => _isLoading = false);

                          if (result == null) {
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const Home(),
                              ),
                            );
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                backgroundColor: Colors.redAccent,
                                content: Text(
                                  AuthenticationHelper().traduzirRetorno(result),
                                  style: const TextStyle(fontSize: 15),
                                ),
                              ),
                            );
                          }
                        });
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green.shade700,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16.0),
                ),
                elevation: 4,
              ),
              child: _isLoading
                  ? const SizedBox(
                      height: 24,
                      width: 24,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2.5,
                      ),
                    )
                  : const Text(
                      'REGISTAR-SE',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.1,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}