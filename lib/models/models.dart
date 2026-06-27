// ═══════════════════════════════════════════════════════════════
// models.dart  —  STT7 Lê Thị Kim Ngân
// BiometricSnapshot | UserModel | PredictionResult | RiskFactor
// ═══════════════════════════════════════════════════════════════

class BiometricSnapshot {
  final double heartRate;
  final double spo2;
  final double sleepHours;
  final double stressScore;
  final double bmi;
  final int    steps;
  final double calories;
  final DateTime fetchedAt;
  final bool isSimulated;

  const BiometricSnapshot({
    required this.heartRate,
    required this.spo2,
    required this.sleepHours,
    required this.stressScore,
    required this.bmi,
    required this.steps,
    required this.calories,
    required this.fetchedAt,
    this.isSimulated = false,
  });

  factory BiometricSnapshot.defaultValues() => BiometricSnapshot(
    heartRate: 72, spo2: 98, sleepHours: 7, stressScore: 30,
    bmi: 22, steps: 5000, calories: 1800,
    fetchedAt: DateTime.now(), isSimulated: true,
  );

  factory BiometricSnapshot.fromJson(Map<String, dynamic> j) => BiometricSnapshot(
    heartRate:   (j['heart_rate']   ?? 72).toDouble(),
    spo2:        (j['spo2']         ?? 98).toDouble(),
    sleepHours:  (j['sleep_hours']  ?? 7).toDouble(),
    stressScore: (j['stress_score'] ?? 30).toDouble(),
    bmi:         (j['bmi']          ?? 22).toDouble(),
    steps:       (j['steps']        ?? 0).toInt(),
    calories:    (j['calories']     ?? 0).toDouble(),
    fetchedAt:   DateTime.tryParse(j['fetched_at'] ?? '') ?? DateTime.now(),
    isSimulated: j['is_simulated']  ?? false,
  );

  Map<String, dynamic> toJson() => {
    'heart_rate': heartRate, 'spo2': spo2, 'sleep_hours': sleepHours,
    'stress_score': stressScore, 'bmi': bmi, 'steps': steps,
    'calories': calories, 'fetched_at': fetchedAt.toIso8601String(),
    'is_simulated': isSimulated,
  };
}

class UserModel {
  final String uid;
  final String name;
  final String email;
  final int    gender;
  final int    age;
  final bool   hypertension;
  final bool   heartDisease;
  final bool   everMarried;
  final int    residenceType;
  final String workType;
  final String smokingStatus;
  final double avgGlucoseLevel;
  final double bmi;

  const UserModel({
    required this.uid,
    required this.name,
    required this.email,
    required this.gender,
    required this.age,
    required this.hypertension,
    required this.heartDisease,
    required this.everMarried,
    required this.residenceType,
    required this.workType,
    required this.smokingStatus,
    required this.avgGlucoseLevel,
    required this.bmi,
  });

  factory UserModel.empty() => const UserModel(
    uid:'', name:'', email:'', gender:0, age:30,
    hypertension:false, heartDisease:false, everMarried:false,
    residenceType:1, workType:'Private', smokingStatus:'never smoked',
    avgGlucoseLevel:100, bmi:22,
  );

  factory UserModel.fromJson(Map<String, dynamic> j) => UserModel(
    uid:             j['uid']              ?? '',
    name:            j['name']             ?? '',
    email:           j['email']            ?? '',
    gender:          j['gender']           ?? 0,
    age:             j['age']              ?? 30,
    hypertension:    j['hypertension']     ?? false,
    heartDisease:    j['heart_disease']    ?? false,
    everMarried:     j['ever_married']     ?? false,
    residenceType:   j['residence_type']   ?? 1,
    workType:        j['work_type']        ?? 'Private',
    smokingStatus:   j['smoking_status']   ?? 'never smoked',
    avgGlucoseLevel: (j['avg_glucose_level'] ?? 100).toDouble(),
    bmi:             (j['bmi']             ?? 22).toDouble(),
  );

  Map<String, dynamic> toJson() => {
    'uid': uid, 'name': name, 'email': email,
    'gender': gender, 'age': age,
    'hypertension': hypertension, 'heart_disease': heartDisease,
    'ever_married': everMarried, 'residence_type': residenceType,
    'work_type': workType, 'smoking_status': smokingStatus,
    'avg_glucose_level': avgGlucoseLevel, 'bmi': bmi,
  };

  Map<String, dynamic> toApiBody(BiometricSnapshot bio) => {
    'gender': gender, 'age': age,
    'hypertension': hypertension ? 1 : 0,
    'heart_disease': heartDisease ? 1 : 0,
    'ever_married': everMarried ? 1 : 0,
    'Residence_type': residenceType,
    'work_type': workType,
    'smoking_status': smokingStatus,
    'avg_glucose_level': avgGlucoseLevel,
    'bmi': bmi,
    'heart_rate': bio.heartRate,
    'spo2': bio.spo2,
    'sleep_hours': bio.sleepHours,
    'stress_score': bio.stressScore,
  };
}

class RiskFactor {
  final String factor;
  final String value;
  final String impact;
  const RiskFactor({required this.factor, required this.value, required this.impact});
  factory RiskFactor.fromJson(Map<String, dynamic> j) =>
      RiskFactor(factor: j['factor']??'', value: j['value']??'', impact: j['impact']??'');
}

class PredictionResult {
  final String   timestamp;
  final double   logisticRegression;
  final double   decisionTree;
  final double   randomForest;
  final double   ensemble;
  final String   riskLevel;
  final String   riskColor;
  final String   recommendation;
  final List<RiskFactor> topRiskFactors;
  final bool     simulationMode;

  const PredictionResult({
    required this.timestamp,
    required this.logisticRegression,
    required this.decisionTree,
    required this.randomForest,
    required this.ensemble,
    required this.riskLevel,
    required this.riskColor,
    required this.recommendation,
    required this.topRiskFactors,
    required this.simulationMode,
  });

  factory PredictionResult.fromJson(Map<String, dynamic> j) => PredictionResult(
    timestamp:          j['timestamp']            ?? '',
    logisticRegression: (j['logistic_regression'] ?? 0).toDouble(),
    decisionTree:       (j['decision_tree']        ?? 0).toDouble(),
    randomForest:       (j['random_forest']        ?? 0).toDouble(),
    ensemble:           (j['ensemble']             ?? 0).toDouble(),
    riskLevel:          j['risk_level']            ?? 'THẤP',
    riskColor:          j['risk_color']            ?? '#4CAF50',
    recommendation:     j['recommendation']        ?? '',
    topRiskFactors: (j['top_risk_factors'] as List? ?? [])
        .map((e) => RiskFactor.fromJson(e as Map<String, dynamic>)).toList(),
    simulationMode:     j['simulation_mode']       ?? true,
  );

  Map<String, dynamic> toFirestore() => {
    'timestamp':  timestamp,
    'ensemble':   ensemble,
    'risk_level': riskLevel,
    'risk_color': riskColor,
    'lr':         logisticRegression,
    'dt':         decisionTree,
    'rf':         randomForest,
  };
}
