import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

enum Direcao { horizontal, vertical }

class TabuleiroGameScreen extends StatefulWidget {
  final String idPartida;
  final String meuUid;

  const TabuleiroGameScreen({
    super.key,
    required this.idPartida,
    required this.meuUid,
  });

  @override
  State<TabuleiroGameScreen> createState() => _TabuleiroGameScreenState();
}

class _TabuleiroGameScreenState extends State<TabuleiroGameScreen> {
  // Configuração da Frota: 1 navio de 3 casas, 1 de 2 casas e 2 de 1 casa
  final List<int> tamanhosNavios = [3, 2, 1, 1];
  
  // Lista que armazena os índices do tabuleiro ocupados por cada navio posicionado
  List<List<int>> naviosPosicionados = [];
  
  // Direção padrão selecionada para o posicionamento
  Direcao direcaoAtual = Direcao.horizontal;

  // Retorna todos os índices ocupados por todos os navios combinados
  List<int> get todosIndicesNavios {
    return naviosPosicionados.expand((n) => n).toList();
  }

  // Retorna o índice do próximo navio a ser colocado (0 a 3)
  int get navioAtualIndex => naviosPosicionados.length;

  // Retorna o tamanho do navio atual que está sendo posicionado
  int? get tamanhoNavioAtual =>
      navioAtualIndex < tamanhosNavios.length ? tamanhosNavios[navioAtualIndex] : null;

  // Mensagem explicativa para a interface
  String get nomeNavioAtual {
    if (tamanhoNavioAtual == null) return "Todos os navios posicionados!";
    return "Posicione o Navio de $tamanhoNavioAtual casa${tamanhoNavioAtual! > 1 ? 's' : ''} (${navioAtualIndex + 1}/${tamanhosNavios.length})";
  }

  // Valida e calcula os índices que o navio irá ocupar
  List<int>? _calcularIndicesNavio(int indexStart, int tamanho, Direcao direcao) {
    int linha = indexStart ~/ 10;
    int coluna = indexStart % 10;
    List<int> indices = [];

    if (direcao == Direcao.horizontal) {
      if (coluna + tamanho > 10) return null; // Ultrapassa a borda direita
      for (int i = 0; i < tamanho; i++) {
        indices.add(linha * 10 + (coluna + i));
      }
    } else {
      if (linha + tamanho > 10) return null; // Ultrapassa a borda inferior
      for (int i = 0; i < tamanho; i++) {
        indices.add((linha + i) * 10 + coluna);
      }
    }

    // Verificar colisão com navios já colocados
    final jaOcupados = todosIndicesNavios;
    for (int idx in indices) {
      if (jaOcupados.contains(idx)) return null; // Sobreposição
    }

    return indices;
  }

  void _tentarPosicionarNavio(int index) {
    if (tamanhoNavioAtual == null) return; // Todos já foram colocados

    List<int>? indices = _calcularIndicesNavio(index, tamanhoNavioAtual!, direcaoAtual);

    if (indices != null) {
      setState(() {
        naviosPosicionados.add(indices);
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Posição inválida! O navio não cabe ou sobrepõe outro.'),
          duration: Duration(seconds: 1),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  void _desfazerUltimoNavio() {
    if (naviosPosicionados.isNotEmpty) {
      setState(() {
        naviosPosicionados.removeLast();
      });
    }
  }

  void _limparNavios() {
    setState(() {
      naviosPosicionados.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Batalha Naval', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('partidas').doc(widget.idPartida).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(
              child: Text('Erro ao carregar partida', style: TextStyle(color: Colors.white)),
            );
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: CircularProgressIndicator(color: Colors.white));
          }

          final dados = snapshot.data!.data() as Map<String, dynamic>;
          
          bool souJogador1 = dados['jogador1']['uid'] == widget.meuUid;
          
          Map<String, dynamic> meusDados = souJogador1 ? dados['jogador1'] : dados['jogador2'];
          Map<String, dynamic> oponenteDados = souJogador1 ? dados['jogador2'] : dados['jogador1'];
          
          String meuCampo = souJogador1 ? 'jogador1' : 'jogador2';
          String oponenteCampo = souJogador1 ? 'jogador2' : 'jogador1';

          String status = dados['status'];
          String vencedor = dados['vencedor'] ?? '';
          bool meuTurno = dados['turnoAtual'] == widget.meuUid;

          // Função para disparar numa posição do mapa inimigo
          Future<void> disparar(int index) async {
            if (!meuTurno || status != 'jogando') return;
            List<dynamic> tirosNoOponente = oponenteDados['tirosRecebidos'];
            if (tirosNoOponente.contains(index)) return;

            bool acertou = oponenteDados['navios'].contains(index);
            List<dynamic> simulacaoTiros = List.from(tirosNoOponente)..add(index);
            bool venceu = oponenteDados['navios'].every((navio) => simulacaoTiros.contains(navio));

            Map<String, dynamic> updates = {
              '$oponenteCampo.tirosRecebidos': FieldValue.arrayUnion([index]),
              'turnoAtual': acertou ? widget.meuUid : oponenteDados['uid'],
            };

            if (venceu) {
              updates['status'] = 'finalizado';
              updates['vencedor'] = widget.meuUid;
            }

            await FirebaseFirestore.instance.collection('partidas').doc(widget.idPartida).update(updates);
          }

          // Confirmar navios posicionados
          Future<void> confirmarNavios() async {
            await FirebaseFirestore.instance.collection('partidas').doc(widget.idPartida).update({
              '$meuCampo.navios': todosIndicesNavios,
              '$meuCampo.pronto': true,
            });

            var docRecente = await FirebaseFirestore.instance.collection('partidas').doc(widget.idPartida).get();
            var dadosRecentes = docRecente.data() as Map<String, dynamic>;
            if (dadosRecentes['jogador1']['pronto'] == true && dadosRecentes['jogador2']['pronto'] == true) {
              await FirebaseFirestore.instance.collection('partidas').doc(widget.idPartida).update({
                'status': 'jogando'
              });
            }
          }

          return Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.blue.shade900,
                  Colors.blue.shade700,
                  Colors.blue.shade500,
                ],
              ),
            ),
            child: SafeArea(
              child: Column(
                children: [
                  // Barra de Informações da Sala
                  Container(
                    margin: const EdgeInsets.all(12),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white12,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Código: ${widget.idPartida}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white),
                        ),
                        IconButton(
                          icon: const Icon(Icons.copy, color: Colors.tealAccent, size: 20),
                          tooltip: 'Copiar código',
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: widget.idPartida));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Código copiado!'), duration: Duration(seconds: 1)),
                            );
                          },
                        )
                      ],
                    ),
                  ),

                  // FASE 1: Aguardando Oponente
                  if (status == 'aguardando') ...[
                    const Spacer(),
                    Card(
                      margin: const EdgeInsets.symmetric(horizontal: 24),
                      elevation: 8,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      child: Padding(
                        padding: const EdgeInsets.all(32.0),
                        child: Column(
                          children: const [
                            CircularProgressIndicator(),
                            SizedBox(height: 24),
                            Text(
                              'Aguardando oponente...',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Partilhe o código da sala com o outro jogador.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const Spacer(),
                  ]

                  // FASE 2: Posicionamento de Navios
                  else if (status == 'posicionando') ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: Colors.black26,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          const Text(
                            'Fase de Posicionamento da Frota',
                            style: TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            nomeNavioAtual,
                            style: const TextStyle(fontSize: 13, color: Colors.yellowAccent, fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              ElevatedButton.icon(
                                onPressed: () {
                                  setState(() {
                                    direcaoAtual = direcaoAtual == Direcao.horizontal
                                        ? Direcao.vertical
                                        : Direcao.horizontal;
                                  });
                                },
                                icon: Icon(
                                  direcaoAtual == Direcao.horizontal
                                      ? Icons.swap_horiz_rounded
                                      : Icons.swap_vert_rounded,
                                ),
                                label: Text(
                                  direcaoAtual == Direcao.horizontal ? 'Horizontal' : 'Vertical',
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue.shade800,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                ),
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                icon: const Icon(Icons.undo, color: Colors.white),
                                tooltip: 'Desfazer último navio',
                                onPressed: naviosPosicionados.isNotEmpty ? _desfazerUltimoNavio : null,
                              ),
                              IconButton(
                                icon: const Icon(Icons.refresh, color: Colors.redAccent),
                                tooltip: 'Limpar todos',
                                onPressed: naviosPosicionados.isNotEmpty ? _limparNavios : null,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: Center(
                        child: FittedBox(
                          child: SizedBox(
                            width: 300,
                            height: 300,
                            child: GridView.builder(
                              physics: const NeverScrollableScrollPhysics(),
                              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 10),
                              itemCount: 100,
                              itemBuilder: (context, index) {
                                bool isOcupado = todosIndicesNavios.contains(index);

                                return GestureDetector(
                                  onTap: () {
                                    if (meusDados['pronto'] == true) return;
                                    _tentarPosicionarNavio(index);
                                  },
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 250),
                                    margin: const EdgeInsets.all(1),
                                    decoration: BoxDecoration(
                                      color: isOcupado ? Colors.green.shade600 : Colors.blue.shade300,
                                      borderRadius: BorderRadius.circular(2),
                                      border: Border.all(color: Colors.blue.shade800, width: 0.5),
                                    ),
                                    child: isOcupado
                                        ? const Center(
                                            child: Icon(Icons.directions_boat, color: Colors.white, size: 14),
                                          )
                                        : null,
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (meusDados['pronto'] == true)
                      const Padding(
                        padding: EdgeInsets.all(12.0),
                        child: Text(
                          'Aguardando oponente confirmar...',
                          style: TextStyle(color: Colors.yellowAccent, fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                      )
                    else
                      ElevatedButton.icon(
                        onPressed: naviosPosicionados.length == tamanhosNavios.length ? confirmarNavios : null,
                        icon: const Icon(Icons.check_circle_outline),
                        label: const Text('Confirmar Posições'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        ),
                      ),
                    const SizedBox(height: 12),
                  ]

                  // FASE 3: Partida Finalizada
                  else if (status == 'finalizado') ...[
                    const Spacer(),
                    Card(
                      margin: const EdgeInsets.symmetric(horizontal: 24),
                      elevation: 10,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                      child: Padding(
                        padding: const EdgeInsets.all(32.0),
                        child: Column(
                          children: [
                            Icon(
                              vencedor == widget.meuUid ? Icons.emoji_events_rounded : Icons.sentiment_dissatisfied_rounded,
                              size: 90,
                              color: vencedor == widget.meuUid ? Colors.amber : Colors.redAccent,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              vencedor == widget.meuUid ? 'VOCÊ VENCEU!' : 'VOCÊ PERDEU!',
                              style: TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.bold,
                                color: vencedor == widget.meuUid ? Colors.green.shade800 : Colors.red.shade800,
                              ),
                            ),
                            const SizedBox(height: 24),
                            ElevatedButton(
                              onPressed: () async {
                                final docRef = FirebaseFirestore.instance.collection('partidas').doc(widget.idPartida);

                                await docRef.update({
                                  '$meuCampo.saiu': true,
                                });

                                final docSnapshot = await docRef.get();
                                if (docSnapshot.exists) {
                                  final dadosAtualizados = docSnapshot.data() as Map<String, dynamic>;
                                  
                                  bool j1Saiu = dadosAtualizados['jogador1']['saiu'] ?? false;
                                  bool j2Saiu = dadosAtualizados['jogador2']['saiu'] ?? false;

                                  if (j1Saiu && j2Saiu) {
                                    await docRef.delete();
                                  }
                                }

                                if (context.mounted) {
                                  Navigator.pop(context);
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue.shade800,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                              ),
                              child: const Text('Voltar ao Menu'),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const Spacer(),
                  ]

                  // FASE 4: Em Jogo
                  else if (status == 'jogando') ...[
                    // Banner de Turno
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      decoration: BoxDecoration(
                        color: meuTurno ? Colors.green.shade600 : Colors.redAccent.shade400,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        meuTurno ? 'SUA VEZ DE ATACAR!' : 'TURNO DO OPONENTE...',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 1.1,
                        ),
                      ),
                    ),

                    // Mar Inimigo
                    const Text('Mar Inimigo (Toque para disparar)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                    const SizedBox(height: 4),
                    Expanded(
                      child: Center(
                        child: FittedBox(
                          child: SizedBox(
                            width: 290,
                            height: 290,
                            child: GridView.builder(
                              physics: const NeverScrollableScrollPhysics(),
                              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 10),
                              itemCount: 100,
                              itemBuilder: (context, index) {
                                bool atirado = oponenteDados['tirosRecebidos'].contains(index);
                                bool hit = atirado && oponenteDados['navios'].contains(index);
                                
                                Color cor = Colors.blue.shade900;
                                if (atirado) cor = hit ? Colors.redAccent : Colors.white60;
                                
                                return GestureDetector(
                                  onTap: () => disparar(index),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 250),
                                    margin: const EdgeInsets.all(1.0),
                                    color: cor,
                                    child: Center(
                                      child: hit 
                                          ? const Icon(Icons.local_fire_department, color: Colors.yellow, size: 16) 
                                          : (atirado ? const Icon(Icons.close, color: Colors.black, size: 16) : null),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                    ),

                    const Divider(thickness: 1.5, color: Colors.white30, height: 12),

                    // Seu Mar
                    const Text('Seu Mar (Sua Frota)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                    const SizedBox(height: 4),
                    Expanded(
                      child: Center(
                        child: FittedBox(
                          child: SizedBox(
                            width: 290,
                            height: 290,
                            child: GridView.builder(
                              physics: const NeverScrollableScrollPhysics(),
                              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 10),
                              itemCount: 100,
                              itemBuilder: (context, index) {
                                bool meuNavio = meusDados['navios'].contains(index);
                                bool tomeiTiro = meusDados['tirosRecebidos'].contains(index);

                                Color cor = Colors.blue.shade300;
                                if (meuNavio) {
                                  cor = tomeiTiro ? Colors.red : Colors.green;
                                } else if (tomeiTiro) cor = Colors.white60;

                                return AnimatedContainer(
                                  duration: const Duration(milliseconds: 250),
                                  margin: const EdgeInsets.all(1.0),
                                  color: cor,
                                  child: Center(
                                    child: (meuNavio && tomeiTiro) 
                                        ? const Icon(Icons.local_fire_department, color: Colors.yellow, size: 16) 
                                        : null,
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ]
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}