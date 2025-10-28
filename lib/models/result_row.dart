class ResultRow {
  final int competitorNumber;
  final String competitorName;
  final String stage;
  final String division;
  final String classification;
  final double points;
  final double time;
  final double hitFactor;
  final double stagePoints;
  final double stagePercentage;

  ResultRow({
    required this.competitorNumber,
    required this.competitorName,
    this.classification = '',
    required this.stage,
    required this.division,
    required this.points,
    required this.time,
    required this.hitFactor,
    required this.stagePoints,
    required this.stagePercentage,
  });

  static List<String> csvHeader() => [
        'competitor_number',
    'competitor_name',
    'class',
        'stage',
        'division',
        'points',
        'time',
        'hit_factor',
        'stage_points',
        'stage_percentage',
      ];

  List<String> toCsvRow() => [
        competitorNumber.toString(),
        '"${competitorName.replaceAll('"', '""')}"',
    '"${classification.replaceAll('"', '""')}"',
        stage.toString(),
        division.toString(),
        points.toStringAsFixed(2),
        time.toStringAsFixed(2),
        hitFactor.toStringAsFixed(4),
        stagePoints.toStringAsFixed(4),
        stagePercentage.toStringAsFixed(2),
      ];
}
