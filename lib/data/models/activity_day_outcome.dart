/// One activity on one calendar day: was it an opportunity, and what happened.
///
/// The durable half of the outcome loop. `behavioral_events` already records
/// that an answer was given, but that table is write-only by design — RLS
/// SELECT is false for every role — and its rows are de-identified rather than
/// deleted when an account goes away. Neither property suits a record the user
/// is shown about themselves, so outcomes live here as well: the event log is
/// the dataset, this is the user's history.
class ActivityDayOutcome {
  final String? id;
  final String userId;
  final String activityId;

  /// The user's calendar day as literal `YYYY-MM-DD` text.
  ///
  /// Never re-parsed into a [DateTime]. A Postgres `date` has no instant, and
  /// giving it one is exactly how "today" becomes "yesterday" for anyone west
  /// of UTC. Every comparison downstream is string or civil-date arithmetic.
  final String localDate;

  /// Whether the app claimed this day's weather suited the activity.
  ///
  /// Always true for rows the app writes today — an opportunity is the only
  /// reason to create one. The column exists so a future "you asked me not to
  /// count this day" can be expressed without deleting history.
  final bool matched;

  /// [DayOutcome.done], [DayOutcome.skipped], or null for unanswered.
  final String? outcome;

  /// Why the user did not go, when they volunteered it. Optional by design:
  /// the answer is recorded before the reason is ever offered.
  final String? reason;

  final DateTime? answeredAt;
  final DateTime? createdAt;

  const ActivityDayOutcome({
    this.id,
    required this.userId,
    required this.activityId,
    required this.localDate,
    this.matched = true,
    this.outcome,
    this.reason,
    this.answeredAt,
    this.createdAt,
  });

  bool get isAnswered =>
      outcome == DayOutcome.done || outcome == DayOutcome.skipped;

  factory ActivityDayOutcome.fromJson(Map<String, dynamic> json) {
    return ActivityDayOutcome(
      id: json['id'] as String?,
      userId: json['user_id'] as String,
      activityId: json['activity_id'] as String,
      localDate: json['local_date'] as String,
      matched: json['matched'] as bool? ?? true,
      outcome: json['outcome'] as String?,
      reason: json['reason'] as String?,
      answeredAt: json['answered_at'] != null
          ? DateTime.parse(json['answered_at'] as String)
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
    );
  }

  /// The insert/upsert payload.
  ///
  /// Null answer fields are *omitted*, not sent as null. Both writes target the
  /// same (user_id, activity_id, local_date) conflict key, so a payload
  /// carrying `outcome: null` would blank a previously recorded answer the next
  /// time the app re-observes that day as an opportunity — the user's completed
  /// day would quietly become unanswered, and then expire.
  Map<String, dynamic> toJson() => {
    if (id != null) 'id': id,
    'user_id': userId,
    'activity_id': activityId,
    'local_date': localDate,
    'matched': matched,
    if (outcome != null) 'outcome': outcome,
    if (reason != null) 'reason': reason,
    if (answeredAt != null) 'answered_at': answeredAt!.toIso8601String(),
  };
}

/// The two answers, stored as text.
///
/// Constants rather than string literals at each call site for the reason
/// `PrecipLevel` documents: a free-form string repeated across the app is how
/// a typo becomes a silent behaviour change no test catches.
abstract class DayOutcome {
  static const String done = 'done';
  static const String skipped = 'skipped';
}
