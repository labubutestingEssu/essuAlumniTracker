/// Utility class for generating batch years consistently across the app
/// 
/// This class standardizes batch year generation across all screens in the alumni tracker app.
/// All batch year dropdowns now use the same range: 2020 to current year (inclusive).
/// 
/// Previously, some screens used different ranges:
/// - Create alumni account screen: 30 years back from current year
/// - Other screens: 2020 to current year
/// 
/// Now all screens use the standardized 2020 to current year range.
class BatchYearUtils {
  /// Generate batch years from 2020 to current year (inclusive)
  /// This is the standard range used across the app
  /// Returns academic year format (e.g., "2020-2021", "2021-2022")
  static List<String> generateBatchYears() {
    return List.generate(
      (DateTime.now().year - 2020 + 1),
      (index) {
        final year = 2020 + index;
        return '$year-${year + 1}';
      },
    );
  }

  /// Generate school year display format (e.g., "2020-2021", "2021-2022")
  /// This is used for UI display while keeping backend values as single years
  static List<String> generateSchoolYearDisplay() {
    return List.generate(
      (DateTime.now().year - 2020 + 1),
      (index) {
        final year = 2020 + index;
        return '$year-${year + 1}';
      },
    );
  }

  /// Convert a single batch year to school year format for display
  /// e.g., "2020" -> "2020-2021"
  static String batchYearToSchoolYear(String batchYear) {
    final year = int.tryParse(batchYear);
    if (year == null) return batchYear;
    return '$year-${year + 1}';
  }

  /// Convert school year display back to batch year for backend
  /// e.g., "2020-2021" -> "2020"
  static String schoolYearToBatchYear(String schoolYear) {
    if (schoolYear.contains('-')) {
      return schoolYear.split('-')[0];
    }
    return schoolYear;
  }

  /// Generate batch years with a custom range
  /// [startYear] - The starting year (inclusive)
  /// [endYear] - The ending year (inclusive), defaults to current year
  static List<String> generateBatchYearsWithRange(int startYear, [int? endYear]) {
    final end = endYear ?? DateTime.now().year;
    return List.generate(
      (end - startYear + 1),
      (index) => (startYear + index).toString(),
    );
  }

  /// Get the current year as a string
  static String getCurrentYear() {
    return DateTime.now().year.toString();
  }

  /// Get the default start year (2020)
  static int getDefaultStartYear() {
    return 2020;
  }
}
