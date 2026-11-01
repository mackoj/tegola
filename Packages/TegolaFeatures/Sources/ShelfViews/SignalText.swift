#if canImport(SwiftUI)
  public import SwiftUI
  public import TegolaDesignSystem
  import TegolaDesignTokens
  public import TegolaModel

  // How a signal reads (F15): the clock's name, its reason in plain words, and the Estimate label every computed
  // state carries (One Roof). Shared by the object's status slot and the signal feed.

  extension Signal {
    /// The clock, as the collector knows it.
    public var title: Text {
      switch clock {
      case "saveBattery": Text("Save battery", bundle: .module)
      case "codeExpiry": Text("Code expiry", bundle: .module)
      case "drinkingWindow": Text("Drinking window", bundle: .module)
      case "serviceRisk": Text("Service", bundle: .module)
      case "mediaRot", "discRot": Text("Media check", bundle: .module)
      case "unfinished": Text("Unfinished", bundle: .module)
      default: Text(verbatim: clock)
      }
    }

    /// Why it reads as it does: "Battery from 1994, usually lasts 25–35 years".
    public var reasonText: Text {
      switch reason {
      case .battery(let since, let swapped, let lasts):
        let year = String(since)
        let low = String(lasts.lowerBound)
        let high = String(lasts.upperBound)
        return swapped
          ? Text("Battery swapped in \(year), usually lasts \(low)–\(high) years", bundle: .module)
          : Text("Battery from \(year), usually lasts \(low)–\(high) years", bundle: .module)
      case .codeExpires(let date):
        let day = date.formatted(.dateTime.day().month(.abbreviated).year())
        return Text("The code expires on \(day)", bundle: .module)
      case .drinkingWindow(let window):
        let from = String(window.lowerBound)
        let to = String(window.upperBound)
        return Text("Best drunk \(from)–\(to)", bundle: .module)
      case .serviced(let last, let months):
        let day = last.formatted(.dateTime.month(.abbreviated).year())
        return Text("Last serviced \(day), due every \(months) months", bundle: .module)
      case .checked(let since, let wasChecked, let years):
        let year = String(since)
        return wasChecked
          ? Text("Last checked in \(year), worth a look every \(years) years", bundle: .module)
          : Text("Made in \(year), worth a look every \(years) years", bundle: .module)
      case .unfinished(let since):
        let day = since.formatted(.dateTime.month(.abbreviated).year())
        return Text("Started \(day), never finished", bundle: .module)
      }
    }
  }

  extension Signal.Remedy {
    public var label: Text {
      switch self {
      case .batterySwap: Text("Log a battery swap", bundle: .module)
      case .backup: Text("Make a backup", bundle: .module)
      case .service: Text("Log a service", bundle: .module)
      }
    }
  }

  extension ObjectStatus {
    /// The swatch it's drawn in: the five are the same everywhere (PD-016).
    public var swatch: StatusSwatch { StatusSwatch(rawValue: rawValue) ?? .fine }

    /// The swatch's name, for a filter: fine · good · watch · act · gone.
    public var label: Text {
      switch self {
      case .fine: Text("Fine", bundle: .module)
      case .good: Text("Good", bundle: .module)
      case .watch: Text("Watch", bundle: .module)
      case .act: Text("Act", bundle: .module)
      case .gone: Text("Gone", bundle: .module)
      }
    }
  }

  /// The mono word every computed state carries (One Roof, "the estimate label").
  public struct EstimateLabel: View {
    public init() {}

    public var body: some View {
      Text("Estimate", bundle: .module)
        .tegolaTextStyle(TegolaType.metaSmall)
        .foregroundStyle(TegolaRole.textMeta)
        .accessibilityIdentifier("signal.estimate")
    }
  }
#endif
