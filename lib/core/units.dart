/// Unit conversion and weather-code naming, shared across features.
///
/// These were file-private to `schedule_tab.dart`, which is fine until
/// something outside that file needs them — the calendar event body needs the
/// condition name and both temperatures. Lifting beats a fourth copy.
library;

/// Stored temperatures are Celsius; `profiles.temperature_unit == 'F'` is the
/// only thing that turns them into Fahrenheit at the edge.
int celsiusToFahrenheit(double celsius) => (celsius * 9 / 5 + 32).round();

/// Stored wind is km/h — converted from the API's m/s once, at parse time.
int kmhToMph(double kmh) => (kmh * 0.621371).round();

/// The human name for a Tomorrow.io weather code.
///
/// The name half of `_weatherIconData`; the icon and tint stay with the widget
/// that draws them. An unknown code reads as 'Clear', matching the icon
/// mapping's own fallback — the schedule already renders a sun for it, and two
/// different answers for the same code would be worse than one imperfect one.
///
/// https://docs.tomorrow.io/reference/data-layers-weather-codes
String weatherConditionName(int weatherCode) => switch (weatherCode) {
  1000 => 'Clear',
  1100 => 'Mostly Clear',
  1101 => 'Partly Cloudy',
  1102 => 'Mostly Cloudy',
  1001 => 'Cloudy',
  2000 => 'Fog',
  2100 => 'Light Fog',
  4000 => 'Drizzle',
  4001 => 'Rain',
  4200 => 'Light Rain',
  4201 => 'Heavy Rain',
  5000 => 'Snow',
  5001 => 'Flurries',
  5100 => 'Light Snow',
  5101 => 'Heavy Snow',
  6000 => 'Freezing Drizzle',
  6001 => 'Freezing Rain',
  6200 => 'Light Freezing Rain',
  6201 => 'Heavy Freezing Rain',
  7000 => 'Ice Pellets',
  7101 => 'Heavy Ice Pellets',
  7102 => 'Light Ice Pellets',
  8000 => 'Thunderstorm',
  _ => 'Clear',
};
