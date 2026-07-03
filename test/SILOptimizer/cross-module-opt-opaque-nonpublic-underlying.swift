// RUN: %empty-directory(%t)
// RUN: split-file %s %t

// RUN: %target-swift-frontend -emit-module -O -wmo -cross-module-optimization -parse-as-library %t/Lib.swift -emit-module-path=%t/Lib.swiftmodule -module-name=Lib -I%t

/// TEST: `stroke(_:shape:)` returns an opaque type whose underlying type mentions
/// a non-public type (`StrokeModifier`). It must not be cross-module serialized:
/// otherwise, deserializing it in the client (which cannot look through the
/// opaque type) yields a function whose entry-block indirect result argument
/// (the concrete underlying type) mismatches its result type (the opaque type),
/// which trips the SIL verifier / crashes the optimizer.
// RUN: %target-swift-frontend -emit-sil -sil-verify-all %t/Client.swift -I%t

// REQUIRES: OS=macosx
// REQUIRES: asserts

//--- Lib.swift
import SwiftUI

public struct Stroke {}

public struct AnyInsettableShape: InsettableShape {
  public func path(in rect: CGRect) -> Path { Path() }
  public func inset(by amount: CGFloat) -> some InsettableShape { self }
}

private struct StrokeModifier<S>: ViewModifier {
  var stroke: Stroke
  var shape: S
  func body(content: Content) -> some View { content }
}

extension View {
  public func stroke(_ stroke: Stroke, shape: some InsettableShape) -> some View {
    modifier(StrokeModifier(stroke: stroke, shape: shape))
  }
}

//--- Client.swift
import Lib
import SwiftUI

struct ElevationModifier: ViewModifier {
  let stroke: Stroke
  let shape: AnyInsettableShape
  func body(content: Content) -> some View {
    content.stroke(stroke, shape: shape)
  }
}
