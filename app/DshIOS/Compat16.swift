//
//  Compat16.swift
//  fish-pocket — iOS 16.0 backports for the SwiftUI APIs the app uses from 16.1, 16.4,
//  17 and 18.
//
//  Drop into app/DshIOS/ (picked up by `path: DshIOS` in project.yml) and add it to the
//  LiveActivity target only if the extension ever needs it — it does not.
//
//  Naming: extension members that would collide with an SDK declaration of the same
//  name (`Animation.snappy`, `View.onGeometryChange`) are renamed instead of shadowed,
//  so overload resolution never depends on availability filtering. `ContentUnavailableView`
//  stays as-is: a type declared in the app module always wins over an imported one.
//

import SwiftUI
import UIKit

// MARK: - Animation.smoothSpring  (was .snappy, iOS 17)

extension Animation {
    /// iOS 17's `.snappy`. Response 0.32 / damping 0.82 is the closest stable equivalent.
    static var smoothSpring: Animation { .spring(response: 0.32, dampingFraction: 0.82) }

    /// `.snappy(duration: 0.2)` — the response follows the requested duration.
    static func smoothSpring(duration: TimeInterval, extraBounce: Double = 0) -> Animation {
        .spring(response: duration, dampingFraction: max(0.6, 1.0 - extraBounce * 0.4))
    }
}

// MARK: - measureGeometry(for:of:action:)  (was onGeometryChange, iOS 18)

extension View {
    /// iOS 18's `onGeometryChange(for:of:action:)`. Same signature, `transform` gets a
    /// `GeometryProxy`, so `.frame(in: .named(...))` call sites work unchanged.
    ///
    /// Measures through a `background`, one layout pass more than the system version.
    /// Watch the self-sizing text editor (ComposerView) and the folded cards
    /// (ConversationView) for a one-frame oscillation.
    func measureGeometry<T: Equatable>(
        for type: T.Type,
        of transform: @escaping (GeometryProxy) -> T,
        action: @escaping (T) -> Void
    ) -> some View {
        modifier(GeometryChangeModifier(transform: transform, action: action))
    }
}

struct GeometryChangeModifier<T: Equatable>: ViewModifier {
    let transform: (GeometryProxy) -> T
    let action: (T) -> Void

    func body(content: Content) -> some View {
        content
            .background(
                GeometryReader { proxy in
                    Color.clear.preference(key: GeometryChangeKey<T>.self, value: transform(proxy))
                }
            )
            .onPreferenceChange(GeometryChangeKey<T>.self) { action($0) }
    }
}

struct GeometryChangeKey<T: Equatable>: PreferenceKey {
    static var defaultValue: T? { nil }
    static func reduce(value: inout T?, nextValue: () -> T?) {
        if let next = nextValue() { value = next }
    }
}

// MARK: - ContentUnavailableView  (iOS 17)

/// Same three shapes the app uses:
///
///     ContentUnavailableView { Label(...) } description: { Text(...) } actions: { Button(...) }
///     ContentUnavailableView("标题", systemImage: "doc")
///     ContentUnavailableView("标题", systemImage: "doc", description: Text("..."))
///     ContentUnavailableView.search(text: query)
struct ContentUnavailableView<Label: View, Description: View, Actions: View>: View {
    @ViewBuilder var label: Label
    @ViewBuilder var description: Description
    @ViewBuilder var actions: Actions

    var body: some View {
        VStack(spacing: 10) {
            label
                .font(.title2.weight(.semibold))
                .foregroundStyle(Palette.ink)
            description
                .font(.subheadline)
                .foregroundStyle(Palette.secondary)
                .multilineTextAlignment(.center)
            if ObjectIdentifier(Actions.self) != ObjectIdentifier(EmptyView.self) {
                actions.padding(.top, 6)
            }
        }
        .frame(maxWidth: 420)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(32)
    }
}

extension ContentUnavailableView where Description == EmptyView, Actions == EmptyView {
    init(_ title: LocalizedStringKey, systemImage: String) {
        self.init {
            SwiftUI.Label(title, systemImage: systemImage)
        } description: {
            EmptyView()
        } actions: {
            EmptyView()
        }
    }
}

extension ContentUnavailableView where Actions == EmptyView {
    init(_ title: LocalizedStringKey, systemImage: String, description: Text? = nil) {
        self.init {
            SwiftUI.Label(title, systemImage: systemImage)
        } description: {
            if let description { description }
        } actions: {
            EmptyView()
        }
    }
}

extension ContentUnavailableView where Description == Text, Actions == EmptyView {
    static func search(text: String?) -> ContentUnavailableView<SwiftUI.Label<Text, Image>, Text, EmptyView> {
        let query = text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return ContentUnavailableView<SwiftUI.Label<Text, Image>, Text, EmptyView> {
            SwiftUI.Label("无结果", systemImage: "magnifyingglass")
        } description: {
            Text(query.isEmpty ? "没有找到结果" : "没有找到「\(query)」")
        } actions: {
            EmptyView()
        }
    }
}

// MARK: - Sheets: presentationCornerRadius / presentationBackground (iOS 16.4)

/// Back-ports the two 16.4 presentation modifiers through UIKit:
/// `UISheetPresentationController.preferredCornerRadius` has been there since iOS 15,
/// and the sheet's own view controller background is what shows through a translucent
/// SwiftUI background.
///
///     .sheetCornerRadius(36)          // was .presentationCornerRadius(36)
///     .sheetBackground(Palette.background)   // was .presentationBackground(...)
struct SheetAppearance: UIViewControllerRepresentable {
    var cornerRadius: CGFloat?
    var background: Color?

    func makeUIViewController(context: Context) -> Probe {
        let probe = Probe()
        probe.cornerRadius = cornerRadius
        probe.background = background.map { UIColor($0) }
        return probe
    }

    func updateUIViewController(_ probe: Probe, context: Context) {
        probe.cornerRadius = cornerRadius
        probe.background = background.map { UIColor($0) }
        probe.apply()
    }

    final class Probe: UIViewController {
        var cornerRadius: CGFloat?
        var background: UIColor?

        override func viewDidLayoutSubviews() {
            super.viewDidLayoutSubviews()
            apply()
        }

        override func didMove(toParent parent: UIViewController?) {
            super.didMove(toParent: parent)
            apply()
        }

        func apply() {
            // The sheet's hosting controller is an ancestor; its presentationController
            // is the UISheetPresentationController.
            var current: UIViewController? = self
            while let vc = current {
                if let sheet = vc.presentationController as? UISheetPresentationController {
                    if let cornerRadius, sheet.preferredCornerRadius != cornerRadius {
                        sheet.preferredCornerRadius = cornerRadius
                    }
                    if let background, vc.view.backgroundColor != background {
                        vc.view.backgroundColor = background
                    }
                    return
                }
                current = vc.parent
            }
        }
    }
}

extension View {
    func sheetCornerRadius(_ radius: CGFloat) -> some View {
        background(SheetAppearance(cornerRadius: radius, background: nil))
    }

    func sheetBackground(_ color: Color) -> some View {
        background(SheetAppearance(cornerRadius: nil, background: color))
    }

    /// Was `.presentationBackgroundInteraction(.enabled)` (iOS 16.4).
    ///
    /// No equivalent exists below 16.4: touches behind a sheet cannot be routed to the
    /// presented view through the public API (it needs a custom UIPresentationController
    /// with a passthrough container). No-op on 16.0–16.3; the sheet stays modal and a tap
    /// behind dismisses it, as any sheet would.
    func sheetBackgroundTappable(_ enabled: Bool = true) -> some View {
        self
    }
}

// MARK: - Scroll: scrollBounceBehavior (iOS 16.4)

enum ScrollBounce16 {
    case automatic
    case always
    case basedOnSize
}

extension View {
    /// Was `.scrollBounceBehavior(...)`. Sets `alwaysBounceVertical` on the enclosing
    /// UIScrollView: `.basedOnSize` is exactly `alwaysBounceVertical = false`.
    func scrollBounce(_ behavior: ScrollBounce16) -> some View {
        background(ScrollBounceProbe(behavior: behavior))
    }
}

struct ScrollBounceProbe: UIViewRepresentable {
    let behavior: ScrollBounce16

    func makeUIView(context: Context) -> ProbeView {
        let view = ProbeView()
        view.isUserInteractionEnabled = false
        view.behavior = behavior
        return view
    }

    func updateUIView(_ view: ProbeView, context: Context) {
        view.behavior = behavior
        view.apply()
    }

    final class ProbeView: UIView {
        var behavior: ScrollBounce16 = .automatic

        override func didMoveToWindow() {
            super.didMoveToWindow()
            apply()
            // SwiftUI installs the scroll view around the content after the first layout.
            DispatchQueue.main.async { [weak self] in self?.apply() }
        }

        override func layoutSubviews() {
            super.layoutSubviews()
            apply()
        }

        func apply() {
            var current: UIView? = superview
            while let view = current {
                if let scroll = view as? UIScrollView {
                    switch behavior {
                    case .automatic:
                        break
                    case .always:
                        if !scroll.alwaysBounceVertical { scroll.alwaysBounceVertical = true }
                    case .basedOnSize:
                        if scroll.alwaysBounceVertical { scroll.alwaysBounceVertical = false }
                    }
                    return
                }
                current = view.superview
            }
        }
    }
}

// MARK: - Scroll anchoring: defaultScrollAnchor(.bottom) (iOS 17)

/// Stands in for `defaultScrollAnchor(.bottom, for: .initialOffset/.sizeChanges)`.
///
///     ScrollViewReader { proxy in
///         ScrollView { content; BottomMark(id: "bottom", space: "timeline", onChange: ...) }
///             .coordinateSpace(name: "timeline")
///             .onAppear { proxy.scrollTo("bottom", anchor: .bottom) }
///     }
struct BottomMark: View {
    let id: String
    var space: String
    var onChange: (CGFloat) -> Void = { _ in }

    var body: some View {
        Color.clear
            .frame(height: 0)
            .id(id)
            .background(
                GeometryReader { proxy in
                    Color.clear.preference(
                        key: BottomDistanceKey.self,
                        value: proxy.frame(in: .named(space)).maxY
                    )
                }
            )
            .onPreferenceChange(BottomDistanceKey.self) { onChange($0) }
    }
}

struct BottomDistanceKey: PreferenceKey {
    static var defaultValue: CGFloat = .zero
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
}

// MARK: - defaultScrollAnchor (iOS 17), for the places that only wanted "open here"

extension View {
    /// iOS 17's `defaultScrollAnchor`. Below 17 the scroll view opens at its natural offset,
    /// which is what these three call sites did before the anchor existed.
    @ViewBuilder
    func scrollAnchor16(_ anchor: UnitPoint) -> some View {
        if #available(iOS 17.0, *) {
            defaultScrollAnchor(anchor)
        } else {
            self
        }
    }
}

// MARK: - inspector (iOS 17): the iPad workbench column

/// `.inspector` on 17+, a sheet on 16. On iPhone the conversation never asks for it
/// (`sizeClass == .regular` is the iPad case), so the fallback only changes iPad.
struct WorkbenchInspector<Panel: View>: ViewModifier {
    @Binding var isPresented: Bool
    @ViewBuilder var panel: () -> Panel

    func body(content: Content) -> some View {
        if #available(iOS 17.0, *) {
            content.inspector(isPresented: $isPresented) {
                panel().inspectorColumnWidth(min: 320, ideal: 420, max: 640)
            }
        } else {
            content.sheet(isPresented: $isPresented) {
                NavigationStack { panel() }
            }
        }
    }
}
