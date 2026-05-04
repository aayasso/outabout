import 'package:outabout/models/activity.dart';

class ConditionMatch {
  final Activity activity;
  final bool isMatch;

  const ConditionMatch({
    required this.activity,
    required this.isMatch,
  });
}
