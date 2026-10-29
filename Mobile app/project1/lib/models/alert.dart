/// Alert from the `alerts` table.
class Alert {
  const Alert({
    required this.id,
    required this.alertType,
    required this.severity,
    required this.message,
    required this.acknowledged,
    required this.createdAt,
    this.relatedDecisionId,
  });

  final int id;
  final String alertType;
  final AlertSeverity severity;
  final String message;
  final bool acknowledged;
  final DateTime createdAt;
  final int? relatedDecisionId;

  factory Alert.fromJson(Map<String, dynamic> json) => Alert(
        id: json['id'] as int,
        alertType: json['alert_type'] as String,
        severity: AlertSeverity.fromString(json['severity'] as String? ?? 'info'),
        message: json['message'] as String,
        acknowledged: json['acknowledged'] as bool? ?? false,
        createdAt: DateTime.parse(json['created_at'] as String),
        relatedDecisionId: json['related_decision_id'] as int?,
      );

  Alert copyWith({bool? acknowledged}) => Alert(
        id: id,
        alertType: alertType,
        severity: severity,
        message: message,
        acknowledged: acknowledged ?? this.acknowledged,
        createdAt: createdAt,
        relatedDecisionId: relatedDecisionId,
      );
}

enum AlertSeverity {
  info,
  warning,
  critical;

  static AlertSeverity fromString(String s) {
    switch (s) {
      case 'warning':  return AlertSeverity.warning;
      case 'critical': return AlertSeverity.critical;
      default:         return AlertSeverity.info;
    }
  }
}
