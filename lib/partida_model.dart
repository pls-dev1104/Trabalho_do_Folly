class Partida {
  final String id;
  final String turnoAtual;
  final List<dynamic> tirosJogador1; 
  final List<dynamic> tirosJogador2;
  final List<dynamic> naviosJogador1;
  final List<dynamic> naviosJogador2;
  final String status;
  final String vencedor;

  Partida({
    required this.id,
    required this.turnoAtual,
    required this.tirosJogador1,
    required this.tirosJogador2,
    required this.naviosJogador1,
    required this.naviosJogador2,
    required this.status,
    required this.vencedor,
  });

  factory Partida.fromFirestore(String id, Map<String, dynamic> data) {
    return Partida(
      id: id,
      turnoAtual: data['turnoAtual'] ?? '',
      tirosJogador1: data['jogador1']?['tirosRecebidos'] ?? [],
      tirosJogador2: data['jogador2']?['tirosRecebidos'] ?? [],
      naviosJogador1: data['jogador1']?['navios'] ?? [],
      naviosJogador2: data['jogador2']?['navios'] ?? [],
      status: data['status'] ?? 'aguardando',
      vencedor: data['vencedor'] ?? '',
    );
  }
}