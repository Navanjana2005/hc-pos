/// AI decision from the `decisions` table.
class Decision {
  const Decision({
    required this.id,
    required this.decisionType,
    required this.reasoning,
    required this.status,
    required this.decidedBy,
    required this.createdAt,
    required this.updatedAt,
    this.targetDeviceId,
    this.targetApplianceId,
    this.targetApplianceName,
    this.targetDeviceName,
  });

  final int id;
  final DecisionType decisionType;
  final Map<String, dynamic> reasoning; // JSONB
  final DecisionStatus status;
  final String decidedBy; // 'ai' | 'user'
  final DateTime createdAt;
  final DateTime updatedAt;
  final int? targetDeviceId;
  final int? targetApplianceId;
  final String? targetApplianceName;
  final String? targetDeviceName;

  /// Human-readable summary extracted from reasoning JSON.
  String get reasoningSummary {
    final summary = reasoning['summary'] as String?;
    final reason  = reasoning['reason'] as String?;
    final action  = reasoning['action'] as String?;
    return summary ?? reason ?? action ?? 'AI decision based on current system state.';
  }

  String get displayTitle {
    switch (decisionType) {
      case DecisionType.switchToSolar:   return 'Switch to Solar';
      case DecisionType.chargeBattery:   return 'Charge Battery';
      case DecisionType.disableAppliance: return targetApplianceName != null
          ? 'Disable ${targetApplianceName!}' : 'Disable Appliance';
      case DecisionType.postponeLoad:    return 'Postpone Load';
      case DecisionType.sendAlert:       return 'Send Alert';
    }
  }

  factory Decision.fromJson(Map<String, dynamic> json) => Decision(
        id: json['id'] as int,
        decisionType: DecisionType.fromString(json['decision_type'] as String),
        reasoning: json['reasoning'] as Map<String, dynamic>? ?? {},
        status: DecisionStatus.fromString(json['status'] as String),
        decidedBy: json['decided_by'] as String? ?? 'ai',
        createdAt: DateTime.parse(json['created_at'] as String),
        updatedAt: DateTime.parse(json['updated_at'] as String),
        targetDeviceId: json['target_device_id'] as int?,
        targetApplianceId: json['target_appliance_id'] as int?,
        targetApplianceName: json['appliances']?['appliance_name'] as String?,
        targetDeviceName: json['devices']?['device_name'] as String?,
      );

  Decision copyWith({DecisionStatus? status}) => Decision(
        id: id,
        decisionType: decisionType,
        reasoning: reasoning,
        status: status ?? this.status,
        decidedBy: decidedBy,
        createdAt: createdAt,
        updatedAt: updatedAt,
        targetDeviceId: targetDeviceId,
        targetApplianceId: targetApplianceId,
        targetApplianceName: targetApplianceName,
        targetDeviceName: targetDeviceName,
      );
}

enum DecisionType {
  switchToSolar,
  chargeBattery,
  disableAppliance,
  postponeLoad,
  sendAlert;

  static DecisionType fromString(String s) {
    switch (s) {
      case 'switch_to_solar':    return DecisionType.switchToSolar;
      case 'charge_battery':     return DecisionType.chargeBattery;
      case 'disable_appliance':  return DecisionType.disableAppliance;
      case 'postpone_load':      return DecisionType.postponeLoad;
      case 'send_alert':         return DecisionType.sendAlert;
      default:                   return DecisionType.sendAlert;
    }
  }
}

enum DecisionStatus {
  proposed,
  approved,
  rejected,
  executed,
  confirmed,
  failed;

  static DecisionStatus fromString(String s) {
    switch (s) {
      case 'proposed':   return DecisionStatus.proposed;
      case 'approved':   return DecisionStatus.approved;
      case 'rejected':   return DecisionStatus.rejected;
      case 'executed':   return DecisionStatus.executed;
      case 'confirmed':  return DecisionStatus.confirmed;
      case 'failed':     return DecisionStatus.failed;
      default:           return DecisionStatus.proposed;
    }
  }

  String get label {
    switch (this) {
      case DecisionStatus.proposed:  return 'Proposed';
      case DecisionStatus.approved:  return 'Approved';
      case DecisionStatus.rejected:  return 'Rejected';
      case DecisionStatus.executed:  return 'Executed';
      case DecisionStatus.confirmed: return 'Confirmed';
      case DecisionStatus.failed:    return 'Failed';
    }
  }

  String get apiValue {
    switch (this) {
      case DecisionStatus.proposed:  return 'proposed';
      case DecisionStatus.approved:  return 'approved';
      case DecisionStatus.rejected:  return 'rejected';
      case DecisionStatus.executed:  return 'executed';
      case DecisionStatus.confirmed: return 'confirmed';
      case DecisionStatus.failed:    return 'failed';
    }
  }
}
