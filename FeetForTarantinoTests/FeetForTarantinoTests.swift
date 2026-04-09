import Foundation
import Testing
@testable import FeetForTarantino

// MARK: - Movie

@Suite("Movie")
@MainActor
struct MovieTests {

    @Test func idUsesTmdbIdWhenDbIdAbsent() {
        let movie = Movie(title: "Inception", tmdbId: 27205)
        #expect(movie.id == 27205)
    }

    @Test func idFallsBackToTitleHash() {
        let movie = Movie(title: "Inception")
        #expect(movie.id == "Inception".hashValue)
    }

    @Test func dbIdTakesPrecedenceOverTmdbId() throws {
        let json = #"{"id":999,"title":"Inception","tmdb_id":27205}"#.data(using: .utf8)!
        let movie = try JSONDecoder().decode(Movie.self, from: json)
        #expect(movie.id == 999)
    }

    @Test func posterURLNilWhenNoPosterPath() {
        let movie = Movie(title: "Test")
        #expect(movie.posterURL == nil)
    }

    @Test func posterURLBuildsCorrectly() {
        let movie = Movie(title: "Test", posterPath: "/abc123.jpg")
        #expect(movie.posterURL == URL(string: "https://image.tmdb.org/t/p/w500/abc123.jpg"))
    }

    @Test func formattedRuntimeNilWhenAbsent() {
        let movie = Movie(title: "Test")
        #expect(movie.formattedRuntime == nil)
    }

    @Test(arguments: zip([59, 60, 90, 152], ["59m", "1h 0m", "1h 30m", "2h 32m"]))
    func formattedRuntime(minutes: Int, expected: String) throws {
        let json = "{\"title\":\"T\",\"runtime\":\(minutes)}".data(using: .utf8)!
        let movie = try JSONDecoder().decode(Movie.self, from: json)
        #expect(movie.formattedRuntime == expected)
    }

    @Test func decodesYearAsInt() throws {
        let json = #"{"title":"T","year":2010}"#.data(using: .utf8)!
        let movie = try JSONDecoder().decode(Movie.self, from: json)
        #expect(movie.year == 2010)
    }

    @Test func decodesYearAsString() throws {
        let json = #"{"title":"T","year":"2010"}"#.data(using: .utf8)!
        let movie = try JSONDecoder().decode(Movie.self, from: json)
        #expect(movie.year == 2010)
    }

    @Test func decodesYearInvalidStringToNil() throws {
        let json = #"{"title":"T","year":"unknown"}"#.data(using: .utf8)!
        let movie = try JSONDecoder().decode(Movie.self, from: json)
        #expect(movie.year == nil)
    }

    @Test func decodesMissingOptionalFieldsAsNil() throws {
        let json = #"{"title":"Minimal"}"#.data(using: .utf8)!
        let movie = try JSONDecoder().decode(Movie.self, from: json)
        #expect(movie.year == nil)
        #expect(movie.rating == nil)
        #expect(movie.posterPath == nil)
        #expect(movie.overview == nil)
        #expect(movie.runtime == nil)
        #expect(movie.director == nil)
        #expect(movie.status == nil)
    }
}

// MARK: - TelegramUser

@Suite("TelegramUser")
@MainActor
struct TelegramUserTests {

    private func decode(_ json: String) throws -> TelegramUser {
        try JSONDecoder().decode(TelegramUser.self, from: json.data(using: .utf8)!)
    }

    @Test func displayNamePrefersUsername() throws {
        let user = try decode(#"{"user_id":1,"first_name":"Alice","last_name":"Smith","username":"alice99","is_bot":false}"#)
        #expect(user.displayName == "@alice99")
    }

    @Test func displayNameUsesFirstAndLastName() throws {
        let user = try decode(#"{"user_id":1,"first_name":"Alice","last_name":"Smith","is_bot":false}"#)
        #expect(user.displayName == "Alice Smith")
    }

    @Test func displayNameFallsBackToFirstName() throws {
        let user = try decode(#"{"user_id":1,"first_name":"Alice","is_bot":false}"#)
        #expect(user.displayName == "Alice")
    }

    @Test func avatarIconIsDeterministic() throws {
        let user = try decode(#"{"user_id":42,"first_name":"Bob","is_bot":false}"#)
        #expect(user.avatarIcon == user.avatarIcon)
        #expect(!user.avatarIcon.isEmpty)
    }

    @Test func avatarIconHandlesNegativeUserId() throws {
        let user = try decode(#"{"user_id":-5,"first_name":"Bot","is_bot":true}"#)
        #expect(!user.avatarIcon.isEmpty)
    }

    @Test func idEqualsUserId() throws {
        let user = try decode(#"{"user_id":7,"first_name":"Carol","is_bot":false}"#)
        #expect(user.id == 7)
    }
}

// MARK: - BasketResponse

@Suite("BasketResponse")
@MainActor
struct BasketResponseTests {

    private func decode(_ json: String) throws -> BasketResponse {
        try JSONDecoder().decode(BasketResponse.self, from: json.data(using: .utf8)!)
    }

    @Test func entriesFlattensMoviesFromSingleUser() throws {
        let json = """
        {
            "by_user": [{
                "user_id": 1, "user_name": "Alice",
                "movies": [
                    {"movie_num": 1, "movie": {"title": "Inception", "tmdb_id": 27205}},
                    {"movie_num": 2, "movie": {"title": "Tenet", "tmdb_id": 503919}}
                ]
            }],
            "unique_count": 2
        }
        """
        let response = try decode(json)
        #expect(response.entries.count == 2)
        #expect(response.entries[0].userId == 1)
        #expect(response.entries[0].userName == "Alice")
        #expect(response.entries[0].movie.title == "Inception")
        #expect(response.entries[1].movie.title == "Tenet")
    }

    @Test func entriesSkipsNilMovies() throws {
        let json = """
        {
            "by_user": [{
                "user_id": 1, "user_name": "Alice",
                "movies": [
                    {"movie_num": 1, "movie": {"title": "Inception"}},
                    {"movie_num": 99, "movie": null}
                ]
            }],
            "unique_count": 1
        }
        """
        let response = try decode(json)
        #expect(response.entries.count == 1)
        #expect(response.entries[0].movie.title == "Inception")
    }

    @Test func entriesFlattensMultipleUsers() throws {
        let json = """
        {
            "by_user": [
                {"user_id": 1, "user_name": "Alice", "movies": [{"movie_num": 1, "movie": {"title": "A"}}]},
                {"user_id": 2, "user_name": "Bob",   "movies": [{"movie_num": 2, "movie": {"title": "B"}}, {"movie_num": 3, "movie": {"title": "C"}}]}
            ],
            "unique_count": 2
        }
        """
        let response = try decode(json)
        #expect(response.entries.count == 3)
        #expect(response.entries[0].userId == 1)
        #expect(response.entries[1].userId == 2)
        #expect(response.entries[2].userId == 2)
    }

    @Test func entriesEmptyWhenNoUsers() throws {
        let json = #"{"by_user":[],"unique_count":0}"#
        let response = try decode(json)
        #expect(response.entries.isEmpty)
    }

    @Test func entryIdIsCompositeKey() throws {
        let json = """
        {
            "by_user": [{"user_id": 3, "user_name": "C",
                         "movies": [{"movie_num": 7, "movie": {"title": "X"}}]}],
            "unique_count": 1
        }
        """
        let response = try decode(json)
        #expect(response.entries[0].id == "3-7")
    }
}

// MARK: - ChatStore

@Suite("ChatStore", .serialized)
@MainActor
struct ChatStoreTests {

    init() {
        UserDefaults.standard.removeObject(forKey: "saved_chats")
        UserDefaults.standard.removeObject(forKey: "selected_user_ids")
        UserDefaults.standard.removeObject(forKey: "username")
    }

    private func deepLink(chatId: Int64 = 111, name: String = "Club",
                          userId: Int? = nil, userName: String? = nil) -> URL {
        var comps = URLComponents()
        comps.scheme = "https"
        comps.host = "danchopon.github.io"
        comps.path = "/feetfortarantino/chat"
        var items: [URLQueryItem] = [
            URLQueryItem(name: "id", value: String(chatId)),
            URLQueryItem(name: "name", value: name)
        ]
        if let userId { items.append(URLQueryItem(name: "user_id", value: String(userId))) }
        if let userName { items.append(URLQueryItem(name: "user_name", value: userName)) }
        comps.queryItems = items
        return comps.url!
    }

    @Test func startsEmpty() {
        let store = ChatStore()
        #expect(store.chats.isEmpty)
        #expect(store.selectedChat == nil)
    }

    @Test func handleValidURLAddsChatAndSelectsIt() {
        let store = ChatStore()
        store.handle(deepLink(chatId: 12345, name: "Movie Club"))
        #expect(store.chats.count == 1)
        #expect(store.chats[0].chatId == 12345)
        #expect(store.chats[0].name == "Movie Club")
        #expect(store.selectedChat?.chatId == 12345)
    }

    @Test func handleDuplicateURLDoesNotAddAgain() {
        let store = ChatStore()
        store.handle(deepLink(chatId: 111, name: "Club"))
        store.handle(deepLink(chatId: 111, name: "Club"))
        #expect(store.chats.count == 1)
    }

    @Test func handleSecondChatSelectsIt() {
        let store = ChatStore()
        store.handle(deepLink(chatId: 111, name: "A"))
        store.handle(deepLink(chatId: 222, name: "B"))
        #expect(store.chats.count == 2)
        #expect(store.selectedChat?.chatId == 222)
    }

    @Test func handleInvalidSchemeIgnored() {
        let store = ChatStore()
        var comps = URLComponents()
        comps.scheme = "ftp"
        comps.host = "danchopon.github.io"
        comps.path = "/feetfortarantino/chat"
        comps.queryItems = [
            URLQueryItem(name: "id", value: "123"),
            URLQueryItem(name: "name", value: "T")
        ]
        store.handle(comps.url!)
        #expect(store.chats.isEmpty)
    }

    @Test func handleWrongHostIgnored() {
        let store = ChatStore()
        var comps = URLComponents()
        comps.scheme = "https"
        comps.host = "evil.com"
        comps.path = "/feetfortarantino/chat"
        comps.queryItems = [
            URLQueryItem(name: "id", value: "123"),
            URLQueryItem(name: "name", value: "T")
        ]
        store.handle(comps.url!)
        #expect(store.chats.isEmpty)
    }

    @Test func handleWithUserNameSavesToUserDefaults() {
        let store = ChatStore()
        store.handle(deepLink(userName: "Tarantino"))
        #expect(UserDefaults.standard.string(forKey: "username") == "Tarantino")
        UserDefaults.standard.removeObject(forKey: "username")
    }

    @Test func handleEmptyUserNameNotSaved() {
        let store = ChatStore()
        UserDefaults.standard.removeObject(forKey: "username")
        store.handle(deepLink(userName: ""))
        #expect(UserDefaults.standard.string(forKey: "username") == nil)
    }

    @Test func removeDeselectsRemovedChat() {
        let store = ChatStore()
        store.handle(deepLink(chatId: 111, name: "A"))
        store.handle(deepLink(chatId: 222, name: "B"))
        store.select(store.chats[0])
        let firstChatId = store.chats[0].chatId
        store.remove(at: IndexSet(integer: 0))
        #expect(store.chats.count == 1)
        #expect(store.selectedChat?.chatId != firstChatId)
    }

    @Test func removeNonSelectedChatKeepsSelection() {
        let store = ChatStore()
        store.handle(deepLink(chatId: 111, name: "A"))
        store.handle(deepLink(chatId: 222, name: "B"))
        store.select(store.chats[0])
        store.remove(at: IndexSet(integer: 1))
        #expect(store.selectedChat?.chatId == 111)
    }

    @Test func removeLastChatClearsSelection() {
        let store = ChatStore()
        store.handle(deepLink(chatId: 111, name: "A"))
        store.remove(at: IndexSet(integer: 0))
        #expect(store.chats.isEmpty)
        #expect(store.selectedChat == nil)
    }

    @Test func selectChatUpdatesSelectedChat() {
        let store = ChatStore()
        store.handle(deepLink(chatId: 111, name: "A"))
        store.handle(deepLink(chatId: 222, name: "B"))
        store.select(store.chats[0])
        #expect(store.selectedChat?.chatId == 111)
    }

    @Test func selectedUserReturnsNilWhenNoUserSelected() {
        let store = ChatStore()
        store.handle(deepLink(chatId: 111, name: "A"))
        #expect(store.selectedUser(for: 111) == nil)
    }

    @Test func selectedUserReturnsNilWhenMembersNotLoaded() {
        let store = ChatStore()
        store.handle(deepLink(chatId: 111, name: "A"))
        // No members in cache — selectedUser must return nil even if user_id was stored
        store.handle(deepLink(chatId: 111, name: "A", userId: 42))
        #expect(store.selectedUser(for: 111) == nil)
    }
}

// MARK: - WatchlistViewModel.StatusFilter

@Suite("WatchlistViewModel.StatusFilter")
struct StatusFilterTests {

    @Test func allHasNilApiValue() {
        #expect(WatchlistViewModel.StatusFilter.all.apiValue == nil)
    }

    @Test func toWatchApiValue() {
        #expect(WatchlistViewModel.StatusFilter.toWatch.apiValue == "to_watch")
    }

    @Test func watchedApiValue() {
        #expect(WatchlistViewModel.StatusFilter.watched.apiValue == "watched")
    }

    @Test func allLabel() {
        #expect(WatchlistViewModel.StatusFilter.all.label == "All")
    }

    @Test func toWatchLabel() {
        #expect(WatchlistViewModel.StatusFilter.toWatch.label == "To Watch")
    }

    @Test func watchedLabel() {
        #expect(WatchlistViewModel.StatusFilter.watched.label == "Watched")
    }

    @Test func hasThreeCases() {
        #expect(WatchlistViewModel.StatusFilter.allCases.count == 3)
    }
}

// MARK: - SearchViewModel

@Suite("SearchViewModel")
struct SearchViewModelTests {

    @Test func initialState() {
        let vm = SearchViewModel()
        #expect(vm.query.isEmpty)
        #expect(vm.results.isEmpty)
        #expect(vm.isLoading == false)
        #expect(vm.isLoadingMore == false)
        #expect(vm.errorMessage == nil)
        #expect(vm.addedMovieIds.isEmpty)
        #expect(vm.addingMovieIds.isEmpty)
    }

    @Test func canLoadMoreFalseInitially() {
        let vm = SearchViewModel()
        // currentPage == totalPages == 1 → no more pages
        #expect(vm.canLoadMore == false)
    }

    @Test func canLoadMoreFalseWhenLoading() {
        let vm = SearchViewModel()
        vm.isLoading = true
        #expect(vm.canLoadMore == false)
    }

    @Test func canLoadMoreFalseWhenLoadingMore() {
        let vm = SearchViewModel()
        vm.isLoadingMore = true
        #expect(vm.canLoadMore == false)
    }
}

// MARK: - MovieNightViewModel

@Suite("MovieNightViewModel")
struct MovieNightViewModelTests {

    private func movie(id: Int, title: String) -> Movie {
        Movie(title: title, tmdbId: id)
    }

    private func entry(userId: Int, name: String, movieNum: Int, movie: Movie) -> BasketEntry {
        BasketEntry(userId: userId, userName: name, movieNum: movieNum, movie: movie)
    }

    @Test func initialState() {
        let vm = MovieNightViewModel()
        #expect(vm.toWatchMovies.isEmpty)
        #expect(vm.myBasket.isEmpty)
        #expect(vm.allBasket.isEmpty)
        #expect(vm.pollMovies.isEmpty)
        #expect(vm.pickedMovie == nil)
        #expect(vm.isLoading == false)
        #expect(vm.isLoadingAction == false)
        #expect(vm.errorMessage == nil)
    }

    @Test func wheelItemsEmptyWithNoBasketOrPoll() {
        let vm = MovieNightViewModel()
        #expect(vm.wheelItems.isEmpty)
    }

    @Test func wheelItemsBuiltFromBasket() {
        let vm = MovieNightViewModel()
        let m = movie(id: 1, title: "Inception")
        vm.allBasket = [
            entry(userId: 1, name: "Alice", movieNum: 1, movie: m),
            entry(userId: 2, name: "Bob",   movieNum: 1, movie: m)
        ]
        let items = vm.wheelItems
        #expect(items.count == 1)
        #expect(items[0].votes == 2)
        #expect(items[0].title == "Inception")
    }

    @Test func wheelItemsPercentagesSumToOne() {
        let vm = MovieNightViewModel()
        vm.allBasket = [
            entry(userId: 1, name: "Alice", movieNum: 1, movie: movie(id: 1, title: "A")),
            entry(userId: 1, name: "Alice", movieNum: 2, movie: movie(id: 2, title: "B")),
            entry(userId: 2, name: "Bob",   movieNum: 3, movie: movie(id: 3, title: "C"))
        ]
        let total = vm.wheelItems.reduce(0.0) { $0 + $1.percentage }
        #expect(abs(total - 1.0) < 0.001)
    }

    @Test func wheelItemsFromPollWhenBasketEmpty() {
        let vm = MovieNightViewModel()
        vm.pollMovies = [movie(id: 1, title: "A"), movie(id: 2, title: "B")]
        let items = vm.wheelItems
        #expect(items.count == 2)
        #expect(abs(items[0].percentage - 0.5) < 0.001)
        #expect(abs(items[1].percentage - 0.5) < 0.001)
    }

    @Test func basketPrevailsOverPollForWheelItems() {
        let vm = MovieNightViewModel()
        vm.allBasket = [entry(userId: 1, name: "Alice", movieNum: 1, movie: movie(id: 1, title: "A"))]
        vm.pollMovies = [movie(id: 2, title: "B")]
        let items = vm.wheelItems
        #expect(items.count == 1)
        #expect(items[0].title == "A")
    }

    @Test func basketCountByUser() {
        let vm = MovieNightViewModel()
        vm.allBasket = [
            entry(userId: 1, name: "Alice", movieNum: 1, movie: movie(id: 1, title: "A")),
            entry(userId: 1, name: "Alice", movieNum: 2, movie: movie(id: 2, title: "B")),
            entry(userId: 2, name: "Bob",   movieNum: 1, movie: movie(id: 1, title: "A"))
        ]
        let counts = vm.basketCountByUser
        #expect(counts[1] == 2)
        #expect(counts[2] == 1)
    }

    @Test func isInMyBasket() {
        let vm = MovieNightViewModel()
        let m = movie(id: 42, title: "Target")
        vm.myBasket = [m]
        #expect(vm.isInMyBasket(m) == true)
        #expect(vm.isInMyBasket(movie(id: 99, title: "Other")) == false)
    }

    @Test func isInMyBasketFalseWhenEmpty() {
        let vm = MovieNightViewModel()
        #expect(vm.isInMyBasket(movie(id: 1, title: "X")) == false)
    }

    @Test func basketByUserGroupsInInsertionOrder() {
        let vm = MovieNightViewModel()
        let m1 = movie(id: 1, title: "A")
        let m2 = movie(id: 2, title: "B")
        vm.allBasket = [
            entry(userId: 1, name: "Alice", movieNum: 1, movie: m1),
            entry(userId: 2, name: "Bob",   movieNum: 1, movie: m1),
            entry(userId: 1, name: "Alice", movieNum: 2, movie: m2)
        ]
        let groups = vm.basketByUser
        #expect(groups.count == 2)
        #expect(groups[0].userId == 1)
        #expect(groups[0].name == "Alice")
        #expect(groups[0].movies.count == 2)
        #expect(groups[1].userId == 2)
        #expect(groups[1].movies.count == 1)
    }

    @Test func basketByUserEmptyWhenNoBasket() {
        let vm = MovieNightViewModel()
        #expect(vm.basketByUser.isEmpty)
    }
}
