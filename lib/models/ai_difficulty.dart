enum AiDifficulty {
  easy(
    label: 'Easy',
    rank: 1,
    description: 'Relaxed and forgiving',
  ),
  medium(
    label: 'Medium',
    rank: 2,
    description: 'Balances progress and pressure',
  ),
  hard(
    label: 'Hard',
    rank: 3,
    description: 'Plans turns ahead and denies momentum',
  );

  const AiDifficulty({
    required this.label,
    required this.rank,
    required this.description,
  });

  final String label;
  final int rank;
  final String description;
}
