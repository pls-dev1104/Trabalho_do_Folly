import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'authentication.dart';
import 'login.dart';
import 'tabuleiro_game_screen.dart';

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  final TextEditingController _salaController = TextEditingController();
  bool _isCreating = false;
  bool _isJoining = false;

  @override
  void dispose() {
    _salaController.dispose();
    super.dispose();
  }

  // Criação de nova sala no Firestore
  Future<void> _criarSala(BuildContext context, String uid) async {
    setState(() => _isCreating = true);
    try {
      String idSala = "SALA_${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}";
      
      await FirebaseFirestore.instance.collection('partidas').doc(idSala).set({
        'status': 'aguardando',
        'turnoAtual': uid,
        'vencedor': '',
        'jogador1': {'uid': uid, 'tirosRecebidos': [], 'navios': [], 'pronto': false},
        'jogador2': {'uid': '', 'tirosRecebidos': [], 'navios': [], 'pronto': false}
      });

      if (!mounted) return;
      setState(() => _isCreating = false);

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => TabuleiroGameScreen(
            idPartida: idSala,
            meuUid: uid,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isCreating = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao criar sala: $e'), backgroundColor: Colors.redAccent),
      );
    }
  }

  // Entrar numa sala existente
  Future<void> _entrarNaSala(BuildContext context, String uid) async {
    String idSala = _salaController.text.trim().toUpperCase();
    if (idSala.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, digite o código da sala.'), backgroundColor: Colors.orange),
      );
      return;
    }

    setState(() => _isJoining = true);
    try {
      final docRef = FirebaseFirestore.instance.collection('partidas').doc(idSala);
      final docSnap = await docRef.get();

      if (!docSnap.exists) {
        if (!mounted) return;
        setState(() => _isJoining = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sala não encontrada! Verifique o código.'), backgroundColor: Colors.redAccent),
        );
        return;
      }

      final dados = docSnap.data();
      if (dados != null && dados['status'] != 'aguardando') {
        if (!mounted) return;
        setState(() => _isJoining = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Esta sala já está cheia ou em andamento.'), backgroundColor: Colors.orange),
        );
        return;
      }

      await docRef.update({
        'jogador2.uid': uid,
        'status': 'posicionando',
      });

      if (!mounted) return;
      setState(() => _isJoining = false);

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => TabuleiroGameScreen(
            idPartida: idSala,
            meuUid: uid,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isJoining = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao entrar na sala: $e'), backgroundColor: Colors.redAccent),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = AuthenticationHelper().user;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Lobby de Batalha', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sair',
            onPressed: () async {
              await AuthenticationHelper().signOut();
              if (context.mounted) {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => const Login()),
                );
              }
            },
          )
        ],
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.blue.shade900,
              Colors.blue.shade700,
              Colors.blue.shade400,
            ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              children: [
                // Cartão do Perfil do Jogador
                Card(
                  elevation: 6,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  color: Colors.white.withValues(alpha: 0.95),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 26,
                          backgroundColor: Colors.blue.shade800,
                          child: const Icon(Icons.person, color: Colors.white, size: 30),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Comandante',
                                style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold),
                              ),
                              Text(
                                user?.email ?? 'Jogador',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Card Criar Nova Sala
                Card(
                  elevation: 8,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      children: [
                        Icon(Icons.add_location_alt_rounded, size: 48, color: Colors.blue.shade800),
                        const SizedBox(height: 12),
                        const Text(
                          'Criar Nova Partida',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Gere um código de sala e convide um amigo para o combate.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey, fontSize: 13),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton.icon(
                            onPressed: _isCreating ? null : () => _criarSala(context, user!.uid),
                            icon: const Icon(Icons.play_arrow_rounded),
                            label: _isCreating
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                  )
                                : const Text('CRIAR NOVA SALA', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue.shade800,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // Card Entrar Numa Sala
                Card(
                  elevation: 8,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      children: [
                        Icon(Icons.vpn_key_rounded, size: 48, color: Colors.green.shade700),
                        const SizedBox(height: 12),
                        const Text(
                          'Entrar numa Sala',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Introduza o código da sala fornecido pelo seu oponente.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey, fontSize: 13),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _salaController,
                          textCapitalization: TextCapitalization.characters,
                          decoration: InputDecoration(
                            labelText: 'Código da Sala (Ex: SALA_1234)',
                            prefixIcon: const Icon(Icons.meeting_room_outlined),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                            filled: true,
                            fillColor: Colors.grey.shade50,
                          ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton.icon(
                            onPressed: _isJoining ? null : () => _entrarNaSala(context, user!.uid),
                            icon: const Icon(Icons.login_rounded),
                            label: _isJoining
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                  )
                                : const Text('ENTRAR NA SALA', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green.shade700,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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
        ),
      ),
    );
  }
}