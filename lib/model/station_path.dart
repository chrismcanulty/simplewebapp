class Mode {
  final String? avoidance;
  final String? errorClear;
  final String? lightSet;
  final double? lowLrfDetectionDistance;
  final double? maxSpeed;
  final String? soundSet;
  final int? soundValume;
  final int? stageTargetPosition;
  final String? arucoMarkerDetection;
  final String? cameraShooting;
  final String? controlAlgorithm;
  final double? cartLateralScale;
  Mode({
    this.avoidance,
    this.errorClear,
    this.lightSet,
    this.lowLrfDetectionDistance,
    this.maxSpeed,
    this.soundSet,
    this.soundValume,
    this.stageTargetPosition,
    this.arucoMarkerDetection,
    this.cameraShooting,
    this.controlAlgorithm,
    this.cartLateralScale,
  });

  factory Mode.fromJson(Map<String, dynamic> json) {
    return Mode(
      avoidance: json['Avoidance'] as String?,
      errorClear: json['Error_clear'] as String?,
      lightSet: json['Light_set'] as String?,
      lowLrfDetectionDistance: json['LowLRF_detection_distance'] as double?,
      maxSpeed: json['Max_speed'] as double?,
      soundSet: json['Sound_set'] as String?,
      soundValume: json['Sound_volume'] as int?,
      stageTargetPosition: json['Stage_target_position'] as int?,
      arucoMarkerDetection: json['ArucoMarker_detection'] as String?,
      cameraShooting: json['Camera_shooting'] as String?,
      controlAlgorithm: json['Control_algorithm'] as String?,
      cartLateralScale: json['Cart_lateral_scale'] as double?,
    );
  }
  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{};
    if (avoidance != null) {
      data['Avoidance'] = avoidance;
    }
    if (errorClear != null) {
      data['Error_clear'] = errorClear;
    }
    if (lightSet != null) {
      data['Light_set'] = lightSet;
    }
    if (lowLrfDetectionDistance != null) {
      data['LowLRF_detection_distance'] = lowLrfDetectionDistance;
    }
    if (maxSpeed != null) {
      data['Max_speed'] = maxSpeed;
    }
    if (soundSet != null) {
      data['Sound_set'] = soundSet;
    }
    if (soundValume != null) {
      data['Sound_volume'] = soundValume;
    }
    if (stageTargetPosition != null) {
      data['Stage_target_position'] = stageTargetPosition;
    }
    if (arucoMarkerDetection != null) {
      data['ArucoMarker_detection'] = arucoMarkerDetection;
    }
    if (cameraShooting != null) {
      data['Camera_shooting'] = cameraShooting;
    }
    if (controlAlgorithm != null) {
      data['Control_algorithm'] = controlAlgorithm;
    }
    if (cartLateralScale != null) {
      data['Cart_lateral_scale'] = cartLateralScale;
    }
    return data;
  }
}

class StationPath {
  final Mode mode;
  final List<String> scenario;

  StationPath({
    required this.mode,
    required this.scenario,
  });

  factory StationPath.fromJson(Map<String, dynamic> json) {
    var modeJson = json['mode'] as Map<String, dynamic>? ?? {};
    var scenarioList = json['scenario'] as List<dynamic>? ?? [];
    return StationPath(
      mode: Mode.fromJson(modeJson),
      scenario: List<String>.from(scenarioList),
    );
  }
  Map<String, dynamic> toJson() {
    return {
      'mode': mode.toJson(),
      'scenario': scenario,
    };
  }
}
