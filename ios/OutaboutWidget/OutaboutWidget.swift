import SwiftUI
import WidgetKit

/// Today's weather and what matches it, on the home screen.
///
/// Glanceable only. The one interaction is a tap, which opens the app at the
/// schedule — the widget itself never fetches, computes or decides anything
/// beyond how stale its data is.
///
/// # Why the timeline is a single entry
///
/// The widget has no API key, no location permission of its own and no
/// Supabase session, so it cannot refresh its own content. Everything comes
/// from the app, which pushes on every forecast refresh and then calls
/// `WidgetCenter.reloadAllTimelines()`. A multi-entry timeline would be
/// pretending to know something about the future that this data does not
/// contain.
///
/// The `.after` policy exists only so the *staleness note* appears without the
/// app running: at the next midnight the same payload starts describing
/// yesterday, and the widget needs to redraw to say so.

struct OutaboutEntry: TimelineEntry {
    let date: Date
    let payload: WidgetPayload?
}

struct OutaboutProvider: TimelineProvider {
    /// The gallery preview, shown before the widget is placed. Deliberately
    /// populated: an empty-state preview reads as a broken widget and is the
    /// difference between being added and being scrolled past.
    func placeholder(in context: Context) -> OutaboutEntry {
        OutaboutEntry(date: Date(), payload: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (OutaboutEntry) -> Void) {
        completion(OutaboutEntry(date: Date(), payload: WidgetPayload.load()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<OutaboutEntry>) -> Void) {
        let entry = OutaboutEntry(date: Date(), payload: WidgetPayload.load())

        // Next local midnight, so the "As of ..." note appears on the day the
        // payload stops being about today rather than whenever the app next
        // happens to open.
        let midnight = Calendar.current.nextDate(
            after: Date(),
            matching: DateComponents(hour: 0, minute: 0),
            matchingPolicy: .nextTime
        ) ?? Date().addingTimeInterval(60 * 60 * 6)

        completion(Timeline(entries: [entry], policy: .after(midnight)))
    }
}

// MARK: - Views

/// Neutral, system-following fallbacks. Reachable only when no payload exists
/// or a payload arrived without colours — never one of the five weather
/// themes, because guessing the weather is exactly what the empty state
/// cannot do.
private enum Fallback {
    static let background = Color(.systemBackground)
    static let surface = Color(.secondarySystemBackground)
    static let text = Color(.label)
    static let textSecondary = Color(.secondaryLabel)
    static let primary = Color.accentColor
}

/// "Open OutAbout to get started" — no data has ever arrived.
///
/// Says what to do rather than what went wrong. From the home screen the user
/// cannot tell a missing App Group from a first install, and in both cases
/// opening the app is the fix.
struct EmptyStateView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: "cloud.sun.fill")
                .font(.title2)
                .foregroundStyle(Fallback.primary)
            Spacer(minLength: 0)
            Text("OutAbout")
                .font(.caption)
                .foregroundStyle(Fallback.textSecondary)
            Text("Open OutAbout to get started")
                .font(.footnote.weight(.medium))
                .foregroundStyle(Fallback.text)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

/// The date line, shown only when the payload is no longer about today.
struct StaleNote: View {
    let payload: WidgetPayload
    let color: Color

    var body: some View {
        if let label = payload.shortDateLabel() {
            Text("As of \(label)")
                .font(.caption2)
                .foregroundStyle(color)
                .lineLimit(1)
        }
    }
}

struct SmallWidgetView: View {
    let payload: WidgetPayload

    var body: some View {
        let text = payload.color(\.text, fallback: Fallback.text)
        let secondary = payload.color(\.textSecondary, fallback: Fallback.textSecondary)
        let accent = payload.color(\.primary, fallback: Fallback.primary)

        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: weatherSymbol(for: payload.weatherCode))
                    .font(.title3)
                    .foregroundStyle(accent)
                Text(payload.temperatureLine)
                    .font(.headline)
                    .foregroundStyle(text)
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
            }
            if let condition = payload.condition {
                Text(condition)
                    .font(.caption)
                    .foregroundStyle(secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            Text(payload.matchSummary)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(payload.count > 0 ? accent : secondary)
                .minimumScaleFactor(0.8)
                .lineLimit(2)
            if payload.isStale() {
                StaleNote(payload: payload, color: secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

struct MediumWidgetView: View {
    let payload: WidgetPayload

    var body: some View {
        let text = payload.color(\.text, fallback: Fallback.text)
        let secondary = payload.color(\.textSecondary, fallback: Fallback.textSecondary)
        let accent = payload.color(\.primary, fallback: Fallback.primary)

        HStack(alignment: .top, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Image(systemName: weatherSymbol(for: payload.weatherCode))
                    .font(.title)
                    .foregroundStyle(accent)
                Text(payload.temperatureLine)
                    .font(.headline)
                    .foregroundStyle(text)
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
                if let condition = payload.condition {
                    Text(condition)
                        .font(.caption)
                        .foregroundStyle(secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                if payload.isStale() {
                    StaleNote(payload: payload, color: secondary)
                }
            }
            .frame(maxWidth: 110, alignment: .leading)

            VStack(alignment: .leading, spacing: 3) {
                Text(payload.matchSummary)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(payload.count > 0 ? accent : secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                ForEach(payload.listedMatches, id: \.self) { name in
                    Text(name)
                        .font(.footnote)
                        .foregroundStyle(text)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                // The count is the true total, so this can never disagree with
                // the summary above it.
                if payload.overflowCount > 0 {
                    Text("+\(payload.overflowCount) more")
                        .font(.caption2)
                        .foregroundStyle(secondary)
                }
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

struct OutaboutWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    var entry: OutaboutProvider.Entry

    var body: some View {
        content
            // Required from iOS 17: a widget that paints its own background
            // instead renders with the wrong insets in StandBy and on the Lock
            // Screen. The colour comes from the payload so the widget wears
            // the same weather theme as the app.
            .containerBackground(for: .widget) {
                entry.payload?.color(\.background, fallback: Fallback.background)
                    ?? Fallback.background
            }
            // One destination, so the whole widget is the target rather than
            // any element inside it. Handled by WidgetLaunchCoordinator.
            .widgetURL(URL(string: "outabout://schedule"))
    }

    @ViewBuilder
    private var content: some View {
        if let payload = entry.payload {
            switch family {
            case .systemMedium: MediumWidgetView(payload: payload)
            default: SmallWidgetView(payload: payload)
            }
        } else {
            EmptyStateView()
        }
    }
}

// MARK: - Widget

struct OutaboutWidget: Widget {
    /// Must match `widgetKind` in `lib/features/widget/widget_gateway.dart`,
    /// which is what `HomeWidget.updateWidget(iOSName:)` reloads.
    static let kind = "OutaboutWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: Self.kind, provider: OutaboutProvider()) { entry in
            OutaboutWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Today's matches")
        .description("Today's weather and the activities that suit it.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

@main
struct OutaboutWidgetBundle: WidgetBundle {
    var body: some Widget {
        OutaboutWidget()
    }
}
