#if canImport(SwiftUI)
  public import SwiftUI

  /// Every tab and every verb that more than one screen uses, defined once: its words, its SF Symbol and its usual
  /// look (D-78). Screens name the action; they don't spell its label again, so "Save" is one key in one catalog,
  /// translated once, and a tab and a button for the same thing can't drift apart.
  ///
  /// A verb that only one screen says (*Hand it over*, *Build my shelf*) stays with that screen.
  public enum TegolaAction: String, CaseIterable, Sendable {
    // The five tabs (PD-117), in their default order.
    case shelf, find, scan, activity, you
    // Leaving and keeping (board 29, state 4).
    case close, cancel, save
    // The object's verbs (PLAN F4, F13, F14).
    case edit, photo, confirm, lend, returnLoan, markBorrowed, giveBack, nudge, share
    // Answers.
    case notNow

    /// The words, from this package's catalog, in the reader's locale.
    public var label: Text {
      switch self {
      case .shelf: Text("Shelf", bundle: .module)
      case .find: Text("Find", bundle: .module)
      case .scan: Text("Scan", bundle: .module)
      case .activity: Text("Activity", bundle: .module)
      case .you: Text("You", bundle: .module)
      case .close: Text("Close", bundle: .module)
      case .cancel: Text("Cancel", bundle: .module)
      case .save: Text("Save", bundle: .module)
      case .edit: Text("Edit", bundle: .module)
      case .photo: Text("Photo", bundle: .module)
      case .confirm: Text("Confirm", bundle: .module)
      case .lend: Text("Lend", bundle: .module)
      case .returnLoan: Text("Mark returned", bundle: .module)
      case .markBorrowed: Text("Whose is it?", bundle: .module)
      case .giveBack: Text("Give back", bundle: .module)
      case .nudge: Text("Nudge", bundle: .module)
      case .share: Text("Share", bundle: .module)
      case .notNow: Text("Not now", bundle: .module)
      }
    }

    /// The SF Symbol, for tabs and icon-only places.
    public var symbol: String {
      switch self {
      case .shelf: "books.vertical"
      case .find: "magnifyingglass"
      case .scan: "plus.viewfinder"
      case .activity: "arrow.left.arrow.right"
      case .you: "person.crop.circle"
      case .close: "xmark"
      case .cancel: "xmark"
      case .save: "checkmark"
      case .edit: "pencil"
      case .photo: "camera"
      case .confirm: "checkmark.seal"
      case .lend: "arrow.up.forward.circle"
      case .returnLoan: "arrow.down.backward.circle"
      case .markBorrowed: "person.crop.circle.badge.questionmark"
      case .giveBack: "arrow.uturn.backward.circle"
      case .nudge: "hand.wave"
      case .share: "square.and.arrow.up"
      case .notNow: "clock"
      }
    }

    /// How it usually looks as a button (board 33). A screen may ask for another look where its layout needs one.
    public var kind: TegolaButtonStyle.Kind {
      switch self {
      case .save, .confirm: .confirm
      case .edit, .lend: .primary
      case .nudge, .share: .accent
      case .close, .cancel: .quiet
      case .shelf, .find, .scan, .activity, .you, .photo, .returnLoan, .markBorrowed, .giveBack, .notNow: .secondary
      }
    }

    /// The label and symbol together: a tab's item, a menu row.
    public var item: some View {
      Label {
        label
      } icon: {
        Image(systemName: symbol)
      }
    }
  }

  /// A button for a shared action: its words and look come from `TegolaAction`, and the screen gives what it does and
  /// the identifier its tests use.
  public struct ActionButton: View {
    let action: TegolaAction
    let kind: TegolaButtonStyle.Kind
    let identifier: String
    let perform: () -> Void

    public init(
      _ action: TegolaAction,
      kind: TegolaButtonStyle.Kind? = nil,
      id identifier: String,
      perform: @escaping () -> Void
    ) {
      self.action = action
      self.kind = kind ?? action.kind
      self.identifier = identifier
      self.perform = perform
    }

    public var body: some View {
      Button(action: perform) { action.label }
        .buttonStyle(.tegola(kind))
        .accessibilityIdentifier(identifier)
    }
  }
#endif
