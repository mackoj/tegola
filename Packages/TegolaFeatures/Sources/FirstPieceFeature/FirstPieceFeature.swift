public import ComposableArchitecture
public import Foundation
public import SQLiteData
public import TegolaCatalogue
public import TegolaClients
public import TegolaModel
public import TegolaStorage

/// The first piece (PLAN F2, page 46): one question, a guess, how it came to you, and a payoff, before the shelf has
/// anything on it. Onboarding is this and nothing else: no categories, no account, no sample data (PD-166, PD-102).
@Reducer
public struct FirstPieceFeature {
  @ObservableState
  public struct State: Equatable {
    @ObservationStateIgnored
    @Fetch(ShelfRequest()) public var snapshot = ShelfSnapshot()
    public var step: Step = .ask
    /// The shot or the library photo, as JPEG. Nil for a piece typed in.
    public var photo: Data?
    public var name = ""
    /// The year the description read, if any: kept with the piece so its clocks have something to read.
    public var year: Int?
    /// What the description named. Kept apart from `type` so **Not quite** can show what was guessed.
    public var guess: TypeGuess?
    /// The type the piece is saved as: the guess, or the collector's pick on *What is it?*. Nil saves a Thing.
    public var type: TypeManifest.ID?
    public var subtype: String?
    public var chip: StoryChip?
    public var line = ""
    public var saved: ObjectID?
    /// The type a piece waits for, when it was saved as a Thing (2B).
    public var awaiting: TypeManifest.ID?
    public var payoff: FirstPiecePayoff?
    public var refusal: ShelfRuleViolation?

    public init() {}

    public enum Step: Hashable, Sendable {
      /// 1: the camera, Type it, Library, Just look around first.
      case ask
      /// The model is describing the photo.
      case reading
      /// 2: the photo, and the guess with That's it / Not quite.
      case recognised
      /// 2, nothing recognised: the dashed *What is it?* field.
      case whatIsIt
      /// 2: *How did it come to you?*
      case story
      /// 2B: the type hasn't shipped, so it's a Thing; Count me in / Not now.
      case notShipped
      /// 3: *Your shelf · 1 piece*.
      case payoff
    }

    /// *What is it?* moves on once the piece has a name; the button says so while it hasn't (clctn journey 1, fault).
    public var canContinue: Bool { !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    /// The story as it's kept: the chip's words and the line, in the collector's language (D-63).
    public var story: String {
      let line = line.trimmingCharacters(in: .whitespacesAndNewlines)
      return [chip?.words, line.isEmpty ? nil : line].compactMap(\.self).joined(separator: " · ")
    }

    /// The reducer's own state; the snapshot is the database's (D-47).
    public static func == (lhs: Self, rhs: Self) -> Bool {
      lhs.step == rhs.step && lhs.photo == rhs.photo && lhs.name == rhs.name && lhs.year == rhs.year
        && lhs.guess == rhs.guess
        && lhs.type == rhs.type && lhs.subtype == rhs.subtype && lhs.chip == rhs.chip && lhs.line == rhs.line
        && lhs.saved == rhs.saved && lhs.awaiting == rhs.awaiting && lhs.payoff == rhs.payoff
        && lhs.refusal == rhs.refusal
    }
  }

  /// *How did it come to you?* (46, screen 02): one chip, then an optional line.
  public enum StoryChip: String, CaseIterable, Hashable, Sendable {
    case gift, bought, inherited, found, sinceChild

    /// The words kept in the story, in the language the collector answered in (D-63).
    public var words: String {
      switch self {
      case .gift: String(localized: "A gift", bundle: .module)
      case .bought: String(localized: "I bought it", bundle: .module)
      case .inherited: String(localized: "Handed down", bundle: .module)
      case .found: String(localized: "I found it", bundle: .module)
      case .sinceChild: String(localized: "Had it since I was a kid", bundle: .module)
      }
    }
  }

  public enum Action: ViewAction {
    case delegate(Delegate)
    case described(PieceDescription)
    case describeFailed
    case saveRefused(ShelfRuleViolation)
    case saved(ObjectID, awaiting: TypeManifest.ID?)
    case typedDescribed(PieceDescription)
    case view(View)

    @CasePathable
    public enum Delegate: Equatable {
      /// **Just look around first**: the shelf, empty, and onboarding doesn't come back.
      case skipped
      /// **One at a time**: the next piece, through Scan.
      case oneAtATime
      /// **That's enough for today**: the shelf, with its one piece.
      case finished
    }

    @CasePathable
    public enum View: Equatable {
      case chipTapped(StoryChip)
      case countMeInTapped
      case lineChanged(String)
      case lookAroundTapped
      case nameChanged(String)
      case nextTapped
      case notNowTapped
      case notQuiteTapped
      case oneAtATimeTapped
      case photoTaken(Data)
      case saveTapped
      case thatsEnoughTapped
      case thatsItTapped
      case typeItTapped
      case typeTapped(TypeManifest.ID)
    }
  }

  @Dependency(\.calendar) var calendar
  @Dependency(\.catalogue) var catalogue
  @Dependency(\.date.now) var now
  @Dependency(\.extraction) var extraction
  @Dependency(\.photoStore) var photoStore
  @Dependency(\.settings) var settings
  @Dependency(\.shelf) var shelf

  public init() {}

  public var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case .delegate:
        return .none

      case .described(let description):
        state.name = description.name ?? ""
        state.year = description.year
        state.guess = catalogue.guess(from: description.guessText)
        state.type = state.guess?.type
        state.subtype = state.guess?.subtype
        state.step = state.canContinue && state.guess != nil ? .recognised : .whatIsIt
        return .none

      case .describeFailed:
        state.step = .whatIsIt
        return .none

      case .saveRefused(let violation):
        state.refusal = violation
        return .none

      case .saved(let id, let awaiting):
        state.saved = id
        state.awaiting = awaiting
        state.refusal = nil
        if awaiting != nil {
          state.step = .notShipped
        } else {
          state.payoff = payoff(for: id, in: state)
          state.step = .payoff
        }
        return .none

      case .typedDescribed(let description):
        // The collector's name stands; the model only adds what kind of thing it is.
        state.guess = catalogue.guess(from: description.guessText)
        state.type = state.guess?.type
        state.subtype = state.guess?.subtype
        state.year = state.year ?? description.year
        state.step = .story
        return .none

      case .view(.chipTapped(let chip)):
        state.chip = state.chip == chip ? nil : chip
        return .none

      case .view(.countMeInTapped):
        guard let type = state.awaiting else { return .none }
        let testers = state.snapshot.typeTesters.adding(type).setting
        state.step = .payoff
        state.payoff = state.saved.flatMap { payoff(for: $0, in: state) }
        return .run { [settings] _ in
          try settings.set(.typeTesters, testers)
        } catch: { error, _ in
          reportIssue(error)
        }

      case .view(.lineChanged(let line)):
        state.line = line
        return .none

      case .view(.lookAroundTapped):
        return .run { [settings] send in
          try settings.set(.firstPieceSkipped, "true")
          await send(.delegate(.skipped))
        } catch: { error, _ in
          reportIssue(error)
        }

      case .view(.nameChanged(let name)):
        state.name = name
        // While the collector hasn't picked a type, the guess follows what they type.
        if state.type == state.guess?.type {
          state.guess = catalogue.guess(from: name)
          state.type = state.guess?.type
          state.subtype = state.guess?.subtype
        }
        return .none

      case .view(.nextTapped):
        guard state.canContinue else { return .none }
        // Nothing picked and nothing guessed from the words alone: the model says what kind of thing the name is.
        guard state.type == nil, extraction.isModelAvailable() else {
          state.step = .story
          return .none
        }
        state.step = .reading
        let name = state.name
        return .run { [extraction] send in
          await send(.typedDescribed(try await extraction.describeText(name)))
        } catch: { error, send in
          reportIssue(error)
          await send(.typedDescribed(PieceDescription()))
        }

      case .view(.notNowTapped):
        state.step = .payoff
        state.payoff = state.saved.flatMap { payoff(for: $0, in: state) }
        return .none

      case .view(.notQuiteTapped):
        state.step = .whatIsIt
        return .none

      case .view(.oneAtATimeTapped):
        return .send(.delegate(.oneAtATime))

      case .view(.photoTaken(let data)):
        state.photo = data
        state.step = .reading
        return .run { [extraction] send in
          await send(.described(try await extraction.describePhoto(data)))
        } catch: { error, send in
          // A model that can't answer is a piece nobody named yet, never an error on screen.
          reportIssue(error)
          await send(.describeFailed)
        }

      case .view(.saveTapped):
        let name = state.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return .none }
        let draft = ObjectDraft.recognised(
          as: state.type ?? "thing",
          subtype: state.subtype,
          values: state.year.map { [.title: .text(name), .year: .year($0)] } ?? [.title: .text(name)],
          catalogue: catalogue
        )
        let command = ShelfCommand.firstPiece(draft, story: state.story, catalogue: catalogue)
        let photo = state.photo
        return .run { [shelf, photoStore, now] send in
          // The photo's file is written before the command that records it (PhotoStoreClient).
          let file = try photo.map { try photoStore.save($0) }
          do {
            let receipt = try shelf.perform(command)
            guard let id = receipt.createdObjects.first else { return }
            if let file {
              do {
                _ = try shelf.perform(.attachPhoto(id, fileName: file, takenAt: now))
              } catch {
                // The piece is saved; a photo that didn't attach is reported, never a reason to save again.
                reportIssue(error)
              }
            }
            await send(.saved(id, awaiting: draft.awaitingType))
          } catch let violation as ShelfRuleViolation {
            await send(.saveRefused(violation))
          }
        } catch: { error, _ in
          reportIssue(error)
        }

      case .view(.thatsEnoughTapped):
        return .send(.delegate(.finished))

      case .view(.thatsItTapped):
        state.step = .story
        return .none

      case .view(.typeItTapped):
        state.photo = nil
        state.step = .whatIsIt
        return .none

      case .view(.typeTapped(let type)):
        if state.type == type {
          state.type = nil
          state.subtype = nil
        } else {
          state.type = type
          state.subtype = state.guess?.type == type ? state.guess?.subtype : nil
        }
        return .none
      }
    }
  }

  /// What the piece tells its collector now, read from the shelf the save just wrote.
  func payoff(for id: ObjectID, in state: State) -> FirstPiecePayoff? {
    @Dependency(\.defaultDatabase) var database
    guard let object = try? database.read({ db in try ShelfRequest().fetch(db) }).shelf.objects[id],
      let type = try? catalogue.resolve(object.typeID, subtype: object.subtype)
    else { return nil }
    return FirstPiecePayoff(object: object, type: type, now: now, calendar: calendar)
  }
}
