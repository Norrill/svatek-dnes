import WidgetKit
import SwiftUI

// MARK: - Entry view (family dispatch)

struct SvatekWidgetEntryView: View {
	@Environment(\.widgetFamily) private var family

	let entry: SvatekEntry

	var body: some View {
		switch family {
		case .systemMedium:
			SvatekMediumView(entry: entry)
				.modifier(SvatekSystemBackground())
		case .accessoryInline:
			SvatekInlineView(day: entry.today)
				.containerBackground(for: .widget) { Color.clear }
		case .accessoryRectangular:
			SvatekRectangularView(entry: entry)
				.containerBackground(for: .widget) { Color.clear }
		case .accessoryCircular:
			SvatekCircularView(day: entry.today)
				.containerBackground(for: .widget) { Color.clear }
		default:
			SvatekSmallView(day: entry.today)
				.modifier(SvatekSystemBackground())
		}
	}
}

/// Subtle brand gradient over the system background – adapts to light/dark mode.
private struct SvatekSystemBackground: ViewModifier {
	func body(content: Content) -> some View {
		content
			.containerBackground(for: .widget) {
				ZStack {
					Color(.systemBackground)
					LinearGradient(
						colors: [Color.brandGreen.opacity(0.14), .clear],
						startPoint: .top,
						endPoint: .bottom
					)
				}
			}
	}
}

// MARK: - Display helpers

private extension SvatekDayData {
	/// Big display line: the names, or the holiday on days without a nameday.
	var headline: String {
		if !names.isEmpty {
			return names.joinedNames
		}
		return holidayShortName ?? String(localized: "nameday_none")
	}

	/// The holiday badge is shown only when the holiday is not already the headline.
	var showsHolidayBadge: Bool {
		holidayShortName != nil && !names.isEmpty
	}

	/// "22. 8." – Czech short date with spaces.
	var shortDateText: String {
		AppFormat.shortDate(month: month, day: day)
	}

	/// First calendar name, falling back to the holiday; nil when the day has neither.
	var previewName: String? {
		names.first ?? holidayShortName
	}

	/// Like `previewName`, but never empty (for compact rows).
	var compactName: String {
		previewName ?? "–"
	}
}

// MARK: - System small

struct SvatekSmallView: View {
	let day: SvatekDayData

	var body: some View {
		VStack(alignment: .leading, spacing: 4) {
			Text(AppFormat.weekdayDayMonth(day.date).uppercased(with: AppFormat.locale))
				.font(.caption2.weight(.semibold))
				.foregroundStyle(.secondary)
				.lineLimit(1)
				.minimumScaleFactor(0.7)

			Spacer(minLength: 2)

			Text(day.headline)
				.font(.title2.weight(.bold))
				.fontDesign(.rounded)
				.foregroundStyle(Color.brandGreen)
				.lineLimit(3)
				.minimumScaleFactor(0.45)

			Spacer(minLength: 2)

			VStack(alignment: .leading, spacing: 3) {
				if day.showsHolidayBadge, let shortName = day.holidayShortName {
					HStack(spacing: 5) {
						HolidayDot(isDayOff: day.isDayOff)
						Text(shortName)
							.font(.caption2)
							.foregroundStyle(.secondary)
							.lineLimit(1)
							.minimumScaleFactor(0.8)
					}
				}
				if !day.contactNames.isEmpty {
					Text("🎉 " + day.contactNames.joinedNames)
						.font(.caption)
						.lineLimit(1)
						.minimumScaleFactor(0.8)
						.accessibilityLabel(Text(String(
							format: String(localized: day.contactNames.count > 1 ? "nameday_has_multiple" : "nameday_has_single"),
							day.contactNames.joinedNames
						)))
				}
			}
		}
		.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
	}
}

// MARK: - System medium

struct SvatekMediumView: View {
	let entry: SvatekEntry

	var body: some View {
		HStack(spacing: 12) {
			SvatekSmallView(day: entry.today)
				.frame(maxWidth: .infinity)

			Divider()

			VStack(alignment: .leading, spacing: 7) {
				ForEach(entry.upcoming.prefix(3), id: \.date) { day in
					SvatekUpcomingRow(day: day)
				}
			}
			.frame(maxWidth: .infinity, alignment: .leading)
		}
	}
}

struct SvatekUpcomingRow: View {
	let day: SvatekDayData

	var body: some View {
		HStack(spacing: 6) {
			Text(day.shortDateText)
				.font(.caption2.monospacedDigit())
				.foregroundStyle(.secondary)
				.lineLimit(1)
				.minimumScaleFactor(0.7)
				.frame(width: 40, alignment: .leading)
			Text(day.compactName)
				.font(.callout.weight(.medium))
				.fontDesign(.rounded)
				.lineLimit(1)
				.minimumScaleFactor(0.7)
			Spacer(minLength: 0)
			if !day.contactNames.isEmpty {
				Text(verbatim: "🎉")
					.font(.caption2)
					.accessibilityLabel("calendar_contact_marker_a11y")
			}
			if day.isDayOff {
				HolidayDot(isDayOff: true, size: 6)
			}
		}
	}
}

// MARK: - Lock screen accessories

struct SvatekInlineView: View {
	let day: SvatekDayData

	var body: some View {
		if !day.names.isEmpty {
			Text(String(format: String(localized: "widget_inline_nameday"), day.names.joinedNames))
		} else if let shortName = day.holidayShortName {
			Text(shortName)
		} else {
			Text("widget_inline_no_nameday")
		}
	}
}

struct SvatekRectangularView: View {
	let entry: SvatekEntry

	var body: some View {
		VStack(alignment: .leading, spacing: 1) {
			Text(entry.today.headline)
				.font(.headline)
				.fontDesign(.rounded)
				.widgetAccentable()
				.lineLimit(1)
				.minimumScaleFactor(0.7)
			if let tomorrow = entry.upcoming.first, let name = tomorrow.previewName {
				Text(String(format: String(localized: "widget_tomorrow_preview"), name))
					.font(.caption)
					.foregroundStyle(.secondary)
					.lineLimit(1)
			}
			if !entry.today.contactNames.isEmpty {
				Text("🎉 " + entry.today.contactNames.joinedNames)
					.font(.caption)
					.lineLimit(1)
					.accessibilityLabel(Text(String(
						format: String(localized: entry.today.contactNames.count > 1 ? "nameday_has_multiple" : "nameday_has_single"),
						entry.today.contactNames.joinedNames
					)))
			}
		}
		.frame(maxWidth: .infinity, alignment: .leading)
	}
}

struct SvatekCircularView: View {
	let day: SvatekDayData

	var body: some View {
		VStack(spacing: -1) {
			Text(verbatim: "\(day.day)")
				.font(.title2.weight(.bold))
				.fontDesign(.rounded)
				.widgetAccentable()
			ViewThatFits(in: .horizontal) {
				Text(day.compactName)
				Text(String(day.compactName.prefix(6)))
			}
			.font(.system(size: 9, weight: .medium, design: .rounded))
			.foregroundStyle(.secondary)
			.lineLimit(1)
		}
	}
}

// MARK: - Previews

#Preview(as: .systemSmall) {
	SvatekWidget()
} timeline: {
	SvatekProvider.entry(at: Date(), snapshot: nil)
}

#Preview(as: .systemMedium) {
	SvatekWidget()
} timeline: {
	SvatekProvider.entry(at: Date(), snapshot: nil)
}
