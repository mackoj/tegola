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
    /// The year the description read, shown on *Is this it?* and editable on *What is it?*: the collector sees it
    /// before it's saved as theirs, so its clocks have something to read.
    public var year: Int?
    /// What the description said kind of thing it is: the guess reads these with whatever name is typed, so a guess
    /// from the photo survives typing its name.
    public var words: [String] = []
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
    /// A save is under way: a second tap does nothing.
    public var isSaving = false
    /// The last save failed for a reason other than the rules.
    public var saveFailed = false

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
        && lhs.refusal == rhs.refusal && lhs.words == rhs.words && lhs.isSaving == rhs.isSaving
        && lhs.saveFailed == rhs.saveFailed
    }

    /// The guess from what the description said and what the collector typed.
    func guessing(_ catalogue: Catalogue) -> TypeGuess? {
      catalogue.guess(from: (words + [name]).joined(separator: " "))
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
    case saveFailed
    case saveRefused(ShelfRuleViolation)
    case saved(ObjectID, awaiting: TypeManifest.ID?)
    case typedDescribed(PieceDescription)
    case view(View)

    @CasePathable
    public enum Delegate: Equatable {
      /// **Close**, after the first screen: the shelf, as it is. Onboarding comes back next launch if it's still empty.
      case closed
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
      case closeTapped
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
      case yearChanged(String)
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
        state.words = description.words
        state.guess = catalogue.guess(from: description.guessText)
        state.type = state.guess?.type
        state.subtype = state.guess?.subtype
        state.step = state.canContinue && state.guess != nil ? .recognised : .whatIsIt
        return .none

      case .describeFailed:
        state.step = .whatIsIt
        return .none

      case .saveFailed:
        state.isSaving = false
        state.saveFailed = true
        return .none

      case .saveRefused(.notTheFirstPiece):
        // The shelf gained an object since onboarding opened (another device's, through sync): this piece is an
        // ordinary one now, typed by the collector, with its story kept as its note.
        state.refusal = .notTheFirstPiece
        return save(&state, asFirstPiece: false)

      case .saveRefused(let violation):
        state.isSaving = false
        state.refusal = violation
        return .none

      case .saved(let id, let awaiting):
        state.isSaving = false
        state.saveFailed = false
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
        // A year the model read from a typed name isn't shown, so it isn't kept: only what the collector saw is.
        state.words = description.words
        state.guess = state.guessing(catalogue)
        state.type = state.guess?.type
        state.subtype = state.guess?.subtype
        state.step = .story
        return .none

      case .view(.chipTapped(let chip)):
        state.chip = state.chip == chip ? nil : chip
        return .none

      case .view(.closeTapped):
        return .send(.delegate(.closed))

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
        // While the collector hasn't picked a type, the guess follows what they type, with the photo's words.
        if state.type == state.guess?.type {
          state.guess = state.guessing(catalogue)
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
        return save(&state, asFirstPiece: true)

      case .view(.thatsEnoughTapped):
        return .send(.delegate(.finished))

      case .view(.thatsItTapped):
        state.step = .story
        return .none

      case .view(.typeItTapped):
        state.photo = nil
        state.step = .whatIsIt
        return .none

      case .view(.yearChanged(let text)):
        let digits = text.filter(\.isNumber)
        state.year = digits.isEmpty ? nil : Int(digits.prefix(4))
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

  /// The one write: the first piece, or, when the shelf has gained an object since, an ordinary typed add with the
  /// story as its note. The photo's file is written before the command that records it (PhotoStoreClient).
  func save(_ state: inout State, asFirstPiece: Bool) -> Effect<Action> {
    let name = state.name.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !name.isEmpty, state.saved == nil, asFirstPiece ? !state.isSaving : true else { return .none }
    state.isSaving = true
    state.saveFailed = false
    var values: [FieldKey: FieldValue] = [.title: .text(name)]
    if let year = state.year { values[.year] = .year(year) }
    let story = state.story
    if !asFirstPiece, !story.isEmpty { values[.notes] = .text(story) }
    let draft = ObjectDraft.recognised(
      as: state.type ?? "thing",
      subtype: state.subtype,
      values: values,
      catalogue: catalogue
    )
    // The fallback goes where Add by hand would: the type's own collection, else a new one named by the type.
    let own = state.snapshot.shelf.collections.values.filter { $0.typeID == draft.type }.min { $0.sortKey < $1.sortKey }
    let collection =
      own.map { CollectionChoice.existing($0.id) }
      ?? .new(name: catalogue.manifest(draft.type)?.name.collection ?? draft.type.rawValue)
    let command =
      asFirstPiece
      ? ShelfCommand.firstPiece(draft, story: story, catalogue: catalogue)
      : .add(draft, to: collection, origin: .typed)
    let photo = state.photo
    return .run { [shelf, photoStore, now] send in
      let file = try photo.map { try photoStore.save($0) }
      do {
        let receipt = try shelf.perform(command)
        guard let id = receipt.createdObjects.first else { return await send(.saveFailed) }
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
    } catch: { error, send in
      reportIssue(error)
      await send(.saveFailed)
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
