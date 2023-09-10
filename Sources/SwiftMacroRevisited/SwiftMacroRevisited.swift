import SwiftUI

@freestanding(expression)
public macro Color(
  _ hex: UInt
) -> SwiftUI.Color = #externalMacro(
  module: "SwiftMacroRevisitedMacros",
  type: "SwiftUIColorHexadecimalLiteralMacro"
)

@freestanding(expression)
public macro Color(
  _ colorSpace: SwiftUI.Color.RGBColorSpace = .sRGB,
  _ hex: UInt
) -> SwiftUI.Color = #externalMacro(
  module: "SwiftMacroRevisitedMacros",
  type: "SwiftUIColorHexadecimalLiteralMacro"
)

#if !USE_VARIADIC_GENERICS_UNWRAP
@freestanding(declaration, names: arbitrary)
public macro unwrap<FirstWrapped, each Wrapped>(
  _ firstValue: FirstWrapped?,
  _ value: repeat (each Wrapped)?,
  body: () -> Void
) = #externalMacro(module: "SwiftMacroRevisitedMacros", type: "UnwrapMacro")
#else
@freestanding(declaration, names: arbitrary)
public macro unwrap(_ values: Any..., body: () -> Void) = #externalMacro(module: "SwiftMacroRevisitedMacros", type: "UnwrapMacro")
#endif
public func reportFailedUnwrapping(
  _ message: String,
  file: StaticString = #file,
  line: UInt = #line
) {
  
}
