import SwiftCompilerPlugin
import SwiftSyntax
import SwiftSyntaxMacros

@_implementationOnly import Foundation
@_implementationOnly import SwiftSyntaxBuilder

enum SwiftUIColorError: Error, CustomStringConvertible {
    case requiresIntegerLiteral
    case malformedHexadecimalRepresentation(string: String)

    var description: String {
        switch self {
        case .requiresIntegerLiteral:
            return "#Color requires an integer literal"
        case .malformedHexadecimalRepresentation(let string):
            return "Invalid hexadecimal representation of RGB color: \(string)"
        }
    }
}

public struct SwiftUIColorHexadecimalLiteralMacro: ExpressionMacro {
  
  static let formatter: NumberFormatter = {
    let formatter = NumberFormatter()
    formatter.maximumFractionDigits = 2
    return formatter
  }()
  
  public static func expansion(
    of node: some FreestandingMacroExpansionSyntax,
    in context: some MacroExpansionContext
  ) throws -> ExprSyntax {
    let hasColorSpace = node.argumentList.count > 1
    
    let i0 = node.argumentList.startIndex
    
    let colorSpace: ExprSyntax = if hasColorSpace {
      node.argumentList[i0].expression.trimmed
    } else {
      """
      SwiftUI.Color.RGBColorSpace.sRGB
      """
    }
    
    let rgbExpr: ExprSyntax = if !hasColorSpace {
      node.argumentList[i0].expression.trimmed
    } else {
      node.argumentList[node.argumentList.index(after: i0)].expression.trimmed
    }
    
    let rgbLiteralExpr = rgbExpr.as(IntegerLiteralExprSyntax.self)
    
    guard case let .integerLiteral(literal) = rgbLiteralExpr?.digits.tokenKind else {
      context.addDiagnostics(
        from: SwiftUIColorError.requiresIntegerLiteral,
        node: node
      )
      return ""
    }
    
    guard let (red, green, blue) = validate(literal) else {
      context.addDiagnostics(
        from: SwiftUIColorError.malformedHexadecimalRepresentation(string: literal),
        node: node
      )
      return ""
    }
    
    let formattedRed = formatter.string(from: NSNumber(floatLiteral: red))!
    let formattedGreen = formatter.string(from: NSNumber(floatLiteral: green))!
    let formattedBlue = formatter.string(from: NSNumber(floatLiteral: blue))!
    
    return
      """
      SwiftUI.Color(\(colorSpace), red: \(raw: formattedRed), green: \(raw: formattedGreen), blue: \(raw: formattedBlue))
      """
  }
  
  static func validate(
    _ colorString: String
  ) -> (red: Double, green: Double, blue: Double)? {
    let hexColorRegex = #"^0x[0-9A-Fa-f]{6}$"#
    let regex = try! NSRegularExpression(pattern: hexColorRegex)
    
    guard regex.firstMatch(
      in: colorString,
      options: [],
      range: NSRange(location: 0, length: colorString.utf16.count)
    ) != nil else {
      return nil
    }
    
    // Valid color. Extract RGB components.
    // Remove the "0x" prefix
    let hexValue = String(colorString.dropFirst(2))
    
    guard let hexNumber = UInt32(hexValue, radix: 16) else {
      return nil
    }
    
    let red = Double((hexNumber & 0xFF0000) >> 16) / 255.0
    let green = Double((hexNumber & 0x00FF00) >> 8) / 255.0
    let blue = Double(hexNumber & 0x0000FF) / 255.0
    
    return (red: red, green: green, blue: blue)
  }
  
}

public struct UnwrapMacro: DeclarationMacro {
  
  enum Version {
    case naïve
    case revision1
  }
  
  static var version: Version = .naïve
  
  public static func expansion(
    of node: some FreestandingMacroExpansionSyntax,
    in context: some MacroExpansionContext
  ) throws -> [DeclSyntax] {
    let wrappedExprs = node.argumentList.filter { eachArg in
      eachArg.label?.text != "body"
    }.map({$0.expression})
    let bodyExpr = node.argumentList.filter { eachArg in
      eachArg.label?.text == "body"
    }.first?.expression.as(ClosureExprSyntax.self) ?? node.trailingClosure!
    
    let loc = context.location(of: node, at: .afterLeadingTrivia, filePathMode: .filePath)!
    
    let unwrapping = wrappedExprs.map { wrappedValue -> DeclSyntax in
      """
      guard let \(wrappedValue) else {
        #if DEBUG
        SwiftMacroRevisited.reportFailedUnwrapping("Unexpected nil value: \(wrappedValue)", file: \(loc.file), line: \(loc.line))
        #endif
        return
      }
      """
    }.map({$0.with(\.trailingTrivia, .newline)})
    
    let body: [DeclSyntax] = switch version {
    case .naïve:
      bodyExpr.statements.map { eachStmt -> DeclSyntax in
        """
        \(eachStmt.trimmed)
        """
      }.map({$0.with(\.trailingTrivia, .newline)})
    case .revision1:
      [
        """
        \(bodyExpr)()
        """
      ]
    }
    
    return unwrapping + body
  }
  
}

public struct DictionaryLikeMacro: MemberMacro {
  
  public static func expansion<Declaration, Context>(of node: AttributeSyntax, providingMembersOf declaration: Declaration, in context: Context) throws -> [DeclSyntax] where Declaration : DeclGroupSyntax, Context : MacroExpansionContext {
    return [
      """
      var _$storage: [String : Any] = [:]
      
      subscript(_ key: String) -> Any? {
        get {
          return _$storage[key]
        }
        set {
          _$storage[key] = newValue
        }
      }
      """
    ]
  }
  
}

public struct UseDictionaryStorageMacro: AccessorMacro {
  
  public static func expansion(of node: AttributeSyntax, providingAccessorsOf declaration: some DeclSyntaxProtocol, in context: some MacroExpansionContext) throws -> [AccessorDeclSyntax] {
    guard let varDecl = declaration.as(VariableDeclSyntax.self) else {
      return []
    }
    // This is a demo project. We don't consider fix the case that a property
    // declaration have multiple variable bindings.
    guard let firstBinding = varDecl.bindings.first else {
      return []
    }
    guard let identPattern = firstBinding.pattern.as(IdentifierPatternSyntax.self) else {
      return []
    }
    guard let type = firstBinding.typeAnnotation?.type else {
      return []
    }
    let key = identPattern.identifier.trimmed
    let keyString = StringLiteralExprSyntax(content: key.text)
    return [
      """
      get {
        return _$storage[\(keyString)] as? \(type)
      }
      """,
      """
      set {
        _$storage[\(keyString)] = newValue
      }
      """
    ]
  }
  
}

public struct UniqueNameMacro: DeclarationMacro {
  
  public static func expansion(of node: some FreestandingMacroExpansionSyntax, in context: some MacroExpansionContext) throws -> [DeclSyntax] {
    return [
      """
      let \(context.makeUniqueName("")) = 0
      """
    ]
  }
  
}

@main
struct SwiftMacroRevisitedPlugin: CompilerPlugin {
  
    let providingMacros: [Macro.Type] = [
      SwiftUIColorHexadecimalLiteralMacro.self,
      UnwrapMacro.self,
      DictionaryLikeMacro.self,
      UseDictionaryStorageMacro.self,
      UniqueNameMacro.self,
    ]
  
}
