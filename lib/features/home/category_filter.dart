import '../../data/models/activity.dart';

/// Pure function for filtering activities by category.
///
/// When [selectedCategoryIds] is empty, all activities are returned
/// (no filter active). Otherwise, returns activities whose
/// [Activity.categoryIds] overlaps with the selected set.
List<Activity> filterActivitiesByCategories(
  List<Activity> activities,
  Set<String> selectedCategoryIds,
) {
  if (selectedCategoryIds.isEmpty) return activities;
  return activities.where((a) {
    return a.categoryIds.any(selectedCategoryIds.contains);
  }).toList();
}
