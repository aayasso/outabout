import 'daily_forecast.dart';
import 'activity.dart';

class ScheduleDay {
  final DailyForecast forecast;
  final List<Activity> matchedActivities;

  const ScheduleDay({required this.forecast, required this.matchedActivities});
}

enum ScheduleLayout { dayFirst, activityFirst }
