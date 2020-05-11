import Foundation

extension Result {
    func andThen<NewSuccess>(
        _ transform: (Success) -> Result<NewSuccess, Failure>
    ) -> Result<NewSuccess, Failure> {
        self.flatMap(transform)
    }

    func andThen<NewSuccess>(
        _ transform: (Success) -> NewSuccess
    ) -> Result<NewSuccess, Failure> {
        self.map(transform)
    }
}

struct MessageEvent: Identifiable, Equatable, CustomStringConvertible {
    let id: Int
    let age: Int
    var body: String

    var description: String {
        "<Message id: \(self.id), age: \(self.age), body: \(self.body.debugDescription)>"
    }
}

struct EditEvent: Identifiable, Equatable, CustomStringConvertible {
    let id: Int
    let age: Int
    var messageId: Int
    var messageBody: String

    var description: String {
        "<Edit id: \(self.id), age: \(self.age), messageId: \(self.messageId), messageBody: \(self.messageBody.debugDescription)>"
    }
}

struct RedactEvent: Identifiable, Equatable, CustomStringConvertible {
    let id: Int
    let age: Int
    var messageId: Int

    var description: String {
        "<Redact id: \(self.id), age: \(self.age), messageId: \(self.messageId)>"
    }
}

struct LikeEvent: Identifiable, Equatable, CustomStringConvertible {
    let id: Int
    let age: Int
    var messageId: Int

    var description: String {
        "<Like id: \(self.id), age: \(self.age), messageId: \(self.messageId)>"
    }
}

enum Event: Identifiable, Equatable, CustomStringConvertible {
    enum Kind: Equatable {
        case root, modifier
    }

    case message(MessageEvent)
    case edit(EditEvent)
    case redact(RedactEvent)
    case like(LikeEvent)

    var id: Int {
        switch self {
        case .message(let event):
            return event.id
        case .redact(let event):
            return event.id
        case .edit(let event):
            return event.id
        case .like(let event):
            return event.id
        }
    }

    var age: Int {
        switch self {
        case .message(let event):
            return event.age
        case .redact(let event):
            return event.age
        case .edit(let event):
            return event.age
        case .like(let event):
            return event.age
        }
    }

    var kind: Kind {
        switch self {
        case .message:
            return .root
        case .edit, .redact, .like:
            return .modifier
        }
    }

    var description: String {
        switch self {
        case .message(let event):
            return event.description
        case .redact(let event):
            return event.description
        case .edit(let event):
            return event.description
        case .like(let event):
            return event.description
        }
    }
}

enum Error: Swift.Error {
    case invalidOperation
}

struct MessageEventViewModel: Identifiable, Equatable, CustomStringConvertible {
    let id: Int
    let age: Int
    var body: String
    var likes: Int = 0

    var description: String {
        "<Message id: \(self.id), age: \(self.age), body: \(self.body.debugDescription), likes: \(self.likes)>"
    }

    public init(id: Int, age: Int, body: String, likes: Int = 0) {
        self.id = id
        self.age = age
        self.body = body
        self.likes = likes
    }

    init(from event: MessageEvent) {
        self.id = event.id
        self.age = event.age
        self.body = event.body
    }

    __consuming func applying(event: Event) -> Result<EventViewModel, Error> {
        switch event {
        case .edit(let edit):
            return self.applying(edit: edit).map { .message($0) }
        case .redact(let redact):
            return self.applying(redact: redact).map { .tombstone($0) }
        case .like(let like):
            return self.applying(like: like).map { .message($0) }
        case _:
            return .failure(.invalidOperation)
        }
    }

    __consuming func applying(edit event: EditEvent) -> Result<Self, Error> {
        guard event.messageId == self.id else {
            return .failure(.invalidOperation)
        }

        var copy = self
        copy.body = event.messageBody

        return .success(copy)
    }

    __consuming func applying(redact event: RedactEvent) -> Result<TombstoneEventViewModel, Error> {
        guard event.messageId == self.id else {
            return .failure(.invalidOperation)
        }

        return .success(.init(id: self.id, age: self.age))
    }

    __consuming func applying(like event: LikeEvent) -> Result<Self, Error> {
        guard event.messageId == self.id else {
            return .failure(.invalidOperation)
        }

        var copy = self
        copy.likes += 1

        return .success(copy)
    }
}

struct TombstoneEventViewModel: Identifiable, Equatable, CustomStringConvertible {
    let id: Int
    let age: Int

    var description: String {
        "<Tombstone id: \(self.id), age: \(self.age)>"
    }

    __consuming func applying(event: Event) -> Result<EventViewModel, Error> {
        return .failure(.invalidOperation)
    }
}

enum EventViewModel: Identifiable, Equatable {
    case message(MessageEventViewModel)
    case tombstone(TombstoneEventViewModel)

    var id: Int {
        switch self {
        case .message(let event):
            return event.id
        case .tombstone(let event):
            return event.id
        }
    }

    __consuming func applying(event: Event) -> Result<Self, Error> {
        switch self {
        case .message(let message):
            return message.applying(event: event)
        case .tombstone(let tombstone):
            return tombstone.applying(event: event)
        }
    }
}

struct RoomState: Equatable {
    struct EventIdByAge: Equatable {
        let id: Int
        let age: Int
    }

    typealias ViewModelsByEventId = [EventViewModel.ID: EventViewModel]
    typealias EventIdsByAge = [EventIdByAge]
    typealias StachedEventsByRelatedEventId = [Event.ID: [Event]]

    private(set) var viewModelsByEventId: ViewModelsByEventId = [:]
    private(set) var eventIdsByAge: EventIdsByAge = []
    internal private(set) var stashedEvents: StachedEventsByRelatedEventId = [:]

    public init(stashedEvents: StachedEventsByRelatedEventId = [:]) {
        self.stashedEvents = stashedEvents
    }

    internal init(
        viewModelsByEventId: ViewModelsByEventId = [:],
        eventIdsByAge: EventIdsByAge = [],
        stashedEvents: StachedEventsByRelatedEventId = [:]
    ) {
        assert(viewModelsByEventId.count == eventIdsByAge.count)
        self.viewModelsByEventId = viewModelsByEventId
        self.eventIdsByAge = eventIdsByAge
        self.stashedEvents = stashedEvents
    }

    private var firstEvent: EventViewModel? {
        self.viewModelsByEventId.first?.value
    }

    mutating func add<S>(events: S) -> Result<(), Error>
    where
        S: Sequence, S.Element == Event
    {
        let monotonicEvents = events.sorted { $0.age < $1.age }

        for event in monotonicEvents {
            switch self.add(event: event) {
            case .success:
                continue
            case .failure(let error):
                return .failure(error)
            }
        }

        return .success(())
    }

    mutating func add(event: Event) -> Result<(), Error> {
        guard self.viewModelsByEventId[event.id] == nil else {
            print("Ignored redundant event")
            return .success(())
        }

        switch event.kind {
        case .root:
            return self.add(root: event)
        case .modifier:
            return self.add(modifier: event)
        }
    }

    mutating func add(root event: Event) -> Result<(), Error> {
        let result: Result<EventViewModel, Error>
        switch event {
        case .message(let messageEvent):
            let viewModel = MessageEventViewModel(from: messageEvent)
            result = .success(.message(viewModel))
        case _:
            fatalError()
        }

        return result.andThen { viewModel in
            self.viewModelsByEventId[event.id] = viewModel
            let insertionIndex = self.eventIdsByAge.insertionIndex(
                of: event.age,
                keyPath: \.age
            )
            let eventIdByAge = EventIdByAge(id: event.id, age: event.age)
            self.eventIdsByAge.insert(eventIdByAge, at: insertionIndex)

            return self.replayStashedEvents(event: event)
        }
    }

    mutating func add(modifier event: Event) -> Result<(), Error> {
        switch event {
        case .edit(let editEvent):
            guard let viewModel = self.viewModelsByEventId[editEvent.messageId] else {
                self.stash(event: event, relatedTo: editEvent.messageId)
                return .success(())
            }
            return viewModel.applying(event: event).andThen {
                self.viewModelsByEventId[viewModel.id] = $0
            }
        case .redact(let redactEvent):
            guard let viewModel = self.viewModelsByEventId[redactEvent.messageId] else {
                self.stash(event: event, relatedTo: redactEvent.messageId)
                return .success(())
            }
            return viewModel.applying(event: event).andThen {
                self.viewModelsByEventId[viewModel.id] = $0
            }
        case .like(let likeEvent):
            guard let viewModel = self.viewModelsByEventId[likeEvent.messageId] else {
                self.stash(event: event, relatedTo: likeEvent.messageId)
                return .success(())
            }
            return viewModel.applying(event: event).andThen {
                self.viewModelsByEventId[viewModel.id] = $0
            }
        case _:
            fatalError()
        }
    }

    private mutating func replayStashedEvents(event: Event) -> Result<(), Error> {
        guard var stashedEvents = self.stashedEvents.removeValue(forKey: event.id) else {
            return .success(())
        }

        // Reverse sort:
        stashedEvents.sort { $0.age > $1.age }

        while let stashedEvent = stashedEvents.popLast() {
            switch self.add(modifier: stashedEvent) {
            case .success:
                continue
            case .failure(let error):
                self.stashedEvents[event.id] = stashedEvents
                return .failure(error)
            }
        }

        return .success(())
    }

    private mutating func stash(event: Event, relatedTo id: Event.ID) {
        self.stashedEvents[id, default: []].append(event)
    }
}

extension Collection where Element: Comparable {
    public func insertionIndex(of value: Element) -> Index {
        self.insertionIndex(
            of: value,
            keyPath: \.self,
            by: { $0 < $1 }
        )
    }

    public func insertionIndex(
        of value: Element,
        by areInIncreasingOrder: (Element, Element) -> Bool
    ) -> Index {
        self.insertionIndex(
            of: value,
            keyPath: \.self,
            by: areInIncreasingOrder
        )
    }
}

extension Collection {
    public func insertionIndex<T>(
        of value: T,
        keyPath: KeyPath<Element, T>
    ) -> Index
    where
        T: Comparable
    {
        self.insertionIndex(
            of: value,
            keyPath: keyPath,
            by: { $0 < $1 }
        )
    }

    /// Search for lower bound of `value` within `self`.
    ///
    /// - Complexity: O(`log2(collection.count)`).
    ///
    /// - Parameters:
    ///   - value: The value to search for
    /// - Returns:
    ///   First index of the first `element` in `collection` for
    ///   which `element < value` evaluates to false or `nil` if `value` is not found.
    public func insertionIndex<T>(
        of value: T,
        keyPath: KeyPath<Element, T>,
        by areInIncreasingOrder: (T, T) -> Bool
    ) -> Index {
        var first = self.startIndex
        var index = first
        var count = self.count
        while count > 0 {
            index = first
            let step = count / 2
            index = self.index(index, offsetBy: step)
            let lhs = self[index][keyPath: keyPath]
            if areInIncreasingOrder(lhs, value) {
                first = self.index(after: index)
                count -= step + 1
            } else {
                count = step
            }
        }
        return first
    }
}
