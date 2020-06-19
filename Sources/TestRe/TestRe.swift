//
// Project: Refresh
// Date: 6/20/20

import Foundation
import SwiftUI
import UIKit

@available(iOS 13.0, *)
struct TestRe<Content: View>: View {
  @State private var previousScrollOffset: CGFloat = 0
  @State private var scrollOffset: CGFloat = 0.5
  @State private var frozen: Bool = false
  @State private var rotation: Angle = .degrees(0)
  @State var refreshing = false
  
  var threshold: CGFloat = 110
  let content: Content
  var onRefresh: ()-> Void

  init(onRefresh: @escaping ()-> Void, @ViewBuilder content: () -> Content) {
    self.content = content()
    self.onRefresh = onRefresh
  }

  var body: some View {
    return VStack {
      ScrollView(showsIndicators: false) {
        ZStack(alignment: .top) {
          MovingView()

          VStack { self.content }.alignmentGuide(
            .top, computeValue: { d in (self.refreshing && self.frozen) ? -self.threshold : 0.0 })
          
            SymbolView(height: self.threshold, loading: self.refreshing,
              frozen: self.frozen, rotation: self.rotation)
        }
      }
      .background(FixedView())
      .onPreferenceChange(RefreshableKeyTypes.PrefKey.self) { values in
        self.refreshLogic(values: values)
      }
    }
  }

  func refreshLogic(values: [RefreshableKeyTypes.PrefData]) {
    DispatchQueue.main.async {
      // Calculate scroll offset
      let movingBounds = values.first { $0.vType == .movingView }?.bounds ?? .zero
      let fixedBounds = values.first { $0.vType == .fixedView }?.bounds ?? .zero

      self.scrollOffset = movingBounds.minY - fixedBounds.minY

      self.rotation = self.symbolRotation(self.scrollOffset)

      // Crossing the threshold on the way down, we start the refresh process
      if !self.refreshing
        && (self.scrollOffset > self.threshold && self.previousScrollOffset <= self.threshold)
      {
        self.refreshing = true
      }

      if self.refreshing {
        // Crossing the threshold on the way up, we add a space at the top of the scrollview
        if self.previousScrollOffset > self.threshold && self.scrollOffset <= self.threshold {
          //                    self.frozen = true
//          if self.homeStore?.currentTopTab == .upcoming {
//            self.homeStore?.send(.loadUpcomingLaunches(shouldRefresh: true))
//          } else if self.homeStore?.currentTopTab == .previous {
//            self.homeStore?.send(.loadPreviousLaunches(shouldRefresh: true))
//          }
//          if let agency = self.newsStore?.beingFiltered {
//            self.newsStore?.send(.loadFiltered(agency, shouldRefresh: true))
//          } else {
//            self.newsStore?.send(.loadRecent(shouldRefresh: true))
//          }
          self.onRefresh()
          self.refreshing = false
        }
      } else {
        // remove the space at the top of the scroll view
        self.frozen = false
      }

      // Update last scroll offset
      self.previousScrollOffset = self.scrollOffset
    }
  }

  func symbolRotation(_ scrollOffset: CGFloat) -> Angle {

    // We will begin rotation, only after we have passed
    // 60% of the way of reaching the threshold.
    if scrollOffset < self.threshold * 0.60 {
      return .degrees(0)
    } else {
      // Calculate rotation, based on the amount of scroll offset
      let h = Double(self.threshold)
      let d = Double(scrollOffset)
      let v = max(min(d - (h * 0.6), h * 0.4), 0)
      return .degrees(180 * v / (h * 0.4))
    }
  }

  struct SymbolView: View {
    var height: CGFloat
    var loading: Bool
    var frozen: Bool
    var rotation: Angle

    var body: some View {
      HStack {
        Circle()
          .trim(from: 0, to: CGFloat(rotation.radians / 3))
          .stroke(
            LinearGradient(
              gradient: Gradient(colors: [
                Color.purple.opacity(self.loading ? 0.6 : 0.8),
                Color.pink.opacity(self.loading ? 1 : 0.9),
              ]), startPoint: .leading, endPoint: .trailing),
            style: StrokeStyle(lineWidth: 4, lineCap: .round)
          )
          .rotationEffect(Angle(degrees: self.loading ? 3000 : 270))
          .frame(width: height * 0.24, height: height * 0.24).fixedSize()
          .padding(.top, height / 1.5)
          .animation(
            self.loading ? Animation.linear.speed(0.08).repeatForever() : Animation.linear.speed(2)
          )
          .offset(y: -height + (loading && frozen ? +height : 0.0))
      }
    }
  }

  struct MovingView: View {
    var body: some View {
      GeometryReader { proxy in
        Color.clear.preference(
          key: RefreshableKeyTypes.PrefKey.self,
          value: [
            RefreshableKeyTypes.PrefData(vType: .movingView, bounds: proxy.frame(in: .global))
          ])
      }.frame(height: 0)
    }
  }

  struct FixedView: View {
    var bounds = UIScreen.main.bounds
    var body: some View {
      Color.clear.preference(
        key: RefreshableKeyTypes.PrefKey.self,
        value: [RefreshableKeyTypes.PrefData(vType: .fixedView, bounds: self.bounds)]
      )
    }
  }
}

struct RefreshableKeyTypes {
  enum ViewType: Int {
    case movingView
    case fixedView
  }

  struct PrefData: Equatable {
    let vType: ViewType
    let bounds: CGRect
  }

  struct PrefKey: PreferenceKey {
    static var defaultValue: [PrefData] = []

    static func reduce(value: inout [PrefData], nextValue: () -> [PrefData]) {
      value.append(contentsOf: nextValue())
    }

    typealias Value = [PrefData]
  }
}

struct ActivityRep: UIViewRepresentable {
  func makeUIView(context: UIViewRepresentableContext<ActivityRep>) -> UIActivityIndicatorView {
    return UIActivityIndicatorView()
  }

  func updateUIView(
    _ uiView: UIActivityIndicatorView, context: UIViewRepresentableContext<ActivityRep>
  ) {
    uiView.startAnimating()
  }
}
