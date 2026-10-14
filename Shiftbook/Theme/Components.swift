import SwiftUI

// MARK: - Cards

struct CardModifier: ViewModifier {
    var padding: CGFloat = 14
    func body(content: Content) -> some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

extension View {
    func card(padding: CGFloat = 14) -> some View { modifier(CardModifier(padding: padding)) }
}

/// A card with punched half-circle notches on both sides, like a paper time card.
/// The notches line up with a `Perforation()` placed inside the content.
struct TicketShape: Shape {
    /// Y position of the notches. nil = middle.
    var notchY: CGFloat?
    var cornerRadius: CGFloat = 18
    var notchRadius: CGFloat = 7

    func path(in rect: CGRect) -> Path {
        let base = Path(roundedRect: rect, cornerRadius: cornerRadius, style: .continuous)
        let y = rect.minY + (notchY ?? rect.height / 2)
        var holes = Path()
        holes.addEllipse(in: CGRect(x: rect.minX - notchRadius, y: y - notchRadius, width: notchRadius * 2, height: notchRadius * 2))
        holes.addEllipse(in: CGRect(x: rect.maxX - notchRadius, y: y - notchRadius, width: notchRadius * 2, height: notchRadius * 2))
        return base.subtracting(holes)
    }
}

private struct PerforationYKey: PreferenceKey {
    static let defaultValue: CGFloat? = nil
    static func reduce(value: inout CGFloat?, nextValue: () -> CGFloat?) {
        value = value ?? nextValue()
    }
}

struct HLine: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.midY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        return p
    }
}

/// Dashed line inside a TicketCard. The side notches line up with it.
struct Perforation: View {
    var body: some View {
        HLine()
            .stroke(Theme.line, style: StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
            .frame(height: 2)
            .padding(.horizontal, 4)
            .background(
                GeometryReader { geo in
                    Color.clear.preference(key: PerforationYKey.self,
                                           value: geo.frame(in: .named("ticket")).midY)
                }
            )
    }
}

struct TicketCard<Content: View>: View {
    var fill: Color
    var content: Content
    @State private var notchY: CGFloat?

    init(fill: Color = Theme.card, @ViewBuilder content: () -> Content) {
        self.fill = fill
        self.content = content()
    }

    var body: some View {
        content
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .coordinateSpace(.named("ticket"))
            .background(TicketShape(notchY: notchY).fill(fill))
            .onPreferenceChange(PerforationYKey.self) { notchY = $0 }
    }
}

// MARK: - Text pieces

struct SectionLabel: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        Text(text.uppercased())
            .font(AppFont.text(11, .semibold, relativeTo: .caption))
            .tracking(1)
            .foregroundStyle(Theme.muted)
    }
}

struct ScreenHeader<Trailing: View>: View {
    let small: String
    let title: String
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 2) {
                Text(small)
                    .font(AppFont.text(13, .medium, relativeTo: .subheadline))
                    .foregroundStyle(Theme.muted)
                Text(title)
                    .font(AppFont.display(32))
                    .foregroundStyle(Theme.ink)
            }
            Spacer()
            trailing
        }
    }
}

extension ScreenHeader where Trailing == EmptyView {
    init(small: String, title: String) {
        self.small = small
        self.title = title
        self.trailing = EmptyView()
    }
}

struct Chip: View {
    enum Style { case green, amber, coral, plain }
    let text: String
    var symbol: String? = nil
    var style: Style = .plain

    var body: some View {
        HStack(spacing: 3) {
            if let symbol { Image(systemName: symbol).font(.system(size: 9, weight: .bold)) }
            Text(text)
        }
        .font(AppFont.text(11, .semibold, relativeTo: .caption2))
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .foregroundStyle(fg)
        .background(bg, in: Capsule())
    }

    private var fg: Color {
        switch style {
        case .green: return Theme.green
        case .amber: return Theme.amber
        case .coral: return Theme.coral
        case .plain: return Theme.muted
        }
    }

    private var bg: Color {
        switch style {
        case .green: return Theme.greenSoft
        case .amber: return Theme.amberSoft
        case .coral: return Theme.coralSoft
        case .plain: return Theme.sunk
        }
    }
}

struct RoundIconButton: View {
    let symbol: String
    var label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Theme.ink)
                .frame(width: 38, height: 38)
                .background(Theme.card, in: Circle())
        }
        .accessibilityLabel(label)
    }
}

// MARK: - Buttons

struct PillButtonStyle: ButtonStyle {
    enum Kind { case ink, green, soft }
    var kind: Kind = .ink

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AppFont.text(15, .semibold, relativeTo: .headline))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .padding(.horizontal, 12)
            .foregroundStyle(fg)
            .background(bg, in: Capsule())
            .opacity(configuration.isPressed ? 0.8 : 1)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }

    private var fg: Color {
        switch kind {
        case .ink: return Theme.onInk
        case .green: return Theme.card
        case .soft: return Theme.ink
        }
    }

    private var bg: Color {
        switch kind {
        case .ink: return Theme.ink
        case .green: return Theme.green
        case .soft: return Theme.sunk
        }
    }
}

extension ButtonStyle where Self == PillButtonStyle {
    static var pillInk: PillButtonStyle { PillButtonStyle(kind: .ink) }
    static var pillGreen: PillButtonStyle { PillButtonStyle(kind: .green) }
    static var pillSoft: PillButtonStyle { PillButtonStyle(kind: .soft) }
}

/// Round + button that floats over a screen.
struct FloatingAddButton: View {
    var label: String
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Image(systemName: "plus")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(Theme.onInk)
                .frame(width: 56, height: 56)
                .background(Theme.ink, in: Circle())
                .shadow(color: .black.opacity(0.25), radius: 12, y: 6)
        }
        .accessibilityLabel(label)
    }
}

/// Date block used on shift rows: big day number over a short weekday.
struct DateBlock: View {
    let date: Date
    var highlighted = false

    var body: some View {
        VStack(spacing: 2) {
            Text(date.formatted(.dateTime.day()))
                .font(AppFont.num(16, medium: true))
                .foregroundStyle(Theme.ink)
            Text(date.formatted(.dateTime.weekday(.abbreviated)).uppercased())
                .font(AppFont.text(9, .bold, relativeTo: .caption2))
                .tracking(0.6)
                .foregroundStyle(Theme.muted)
        }
        .frame(width: 42)
        .padding(.vertical, 7)
        .background(highlighted ? Theme.card : Theme.sunk, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}
