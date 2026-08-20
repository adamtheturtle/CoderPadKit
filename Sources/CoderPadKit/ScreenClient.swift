//
//  ScreenClient.swift
//  coderpad
//
//  Networking client for the CoderPad Screen API (https://api.screen.coderpad.io).
//  A thin, self-contained client rather than a `PaginatedRESTClient` wrapper like
//  `CoderPadClient`, because Screen differs from the Interview API in three ways:
//  it authenticates with an `API-Key` header (not a bearer token), it paginates
//  by offset (`start`/`limit`) instead of a `next_page` cursor URL, and all its
//  timestamps are epoch-millisecond integers (no ISO-8601 date parsing needed).
//
//  Failures are mapped onto the app's existing `CoderPadError` so callers (and
//  the unauthorized/offline UI states) handle Screen and Interview errors the
//  same way — both are CoderPad products and the error envelope (`{"code","message"}`)
//  carries a `message` that `CoderPadError` already surfaces.
//

import Foundation

#if canImport(FoundationNetworking)
    import FoundationNetworking
#endif

public struct ScreenClient {
    // Immutable, Sendable configuration driving pure networking, so these are
    // `nonisolated`: the request methods can run off the main actor rather than
    // being pinned to it by the module's default MainActor isolation.
    public nonisolated let apiKey: String
    public nonisolated let baseURL: URL
    public nonisolated let session: URLSession
    public nonisolated let maximumResponseBodyBytes: Int

    /// The US server. EU customers override with `euBaseURL`.
    public nonisolated static let defaultBaseURL = URL(string: "https://www.codingame.com")!
    /// The EU server, for organizations hosted in the EU region.
    public nonisolated static let euBaseURL = URL(string: "https://www.codingame.eu")!

    /// All endpoints live under this versioned prefix. The version is bumped only
    /// for breaking changes (added response fields are non-breaking — see `ScreenAPI`).
    private nonisolated static let apiPrefix = "/assessment/api/v1.1"
    /// Screen v1.1 documents `limit` as int32 with a maximum of 50 (#103).
    public nonisolated static let maximumPageSize = 50
    public nonisolated static let maximumProductFilterLength = 64
    public nonisolated static let maximumEmailFilterLength = 320
    /// Service limit behind the Screen `CandidateNameTooLong` invitation error (#197).
    public nonisolated static let maximumCandidateNameLength = 100
    /// Documented `product` query values for `GET /tests` (#104).
    public nonisolated static let allowedProductFilters: Set<String> = ["screen", "map"]
    public nonisolated static let defaultMaximumResponseBodyBytes = 10 * 1024 * 1024
    public nonisolated static let maximumErrorBodyBytes = 16 * 1024
    public nonisolated static let maximumFullListPages = 100
    public nonisolated static let maximumFullListItems = 10000

    public nonisolated init(apiKey: String,
                            baseURL: URL = Self.defaultBaseURL,
                            session: URLSession = Self.liveSession,
                            maximumResponseBodyBytes: Int = Self.defaultMaximumResponseBodyBytes) {
        precondition(maximumResponseBodyBytes >= 0, "Response limit must not be negative")
        // Normalize once so whitespace-only and control-bearing keys cannot reach
        // header construction (#161).
        self.apiKey = APIKeyNormalization.normalized(apiKey) ?? ""
        self.baseURL = baseURL
        self.session = session
        self.maximumResponseBodyBytes = maximumResponseBodyBytes
    }

    /// The single construction point for the live session, mirroring `CoderPadClient`.
    public nonisolated static let liveSession: URLSession = .init(configuration: makeLiveConfiguration())

    /// Kept separate from the session so timeout and cache policy are directly testable
    /// (#158 parity, #163).
    public nonisolated static func makeLiveConfiguration() -> URLSessionConfiguration {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 60
        config.timeoutIntervalForResource = 120
        config.urlCache = nil
        config.httpCookieStorage = nil
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        return config
    }

    public nonisolated static func live(apiKey: String, baseURL: URL = Self.defaultBaseURL) -> Self {
        precondition(
            isAllowedProductionBaseURL(baseURL),
            "ScreenClient.live base URL must be a credential-free HTTPS Screen origin."
        )
        return Self(apiKey: apiKey, baseURL: baseURL, session: liveSession)
    }

    // MARK: Campaigns

    /// All test campaigns in the organization. `GET /campaigns`. Decoded tolerantly:
    /// one malformed campaign in the response is dropped rather than hiding every
    /// valid campaign behind a decode error (#896), matching the sessions page (#764).
    public nonisolated func listCampaigns() async throws -> [ScreenCampaign] {
        try await listCampaignsResult().campaigns
    }

    public nonisolated func listCampaignsResult() async throws -> ScreenCampaignListResult {
        let list = try await get(TolerantScreenList<ScreenCampaign>.self, path: "/campaigns")
        return ScreenCampaignListResult(campaigns: list.elements, discardedCount: list.discardedCount)
    }

    /// Invites a candidate to a campaign, creating a test session.
    /// `POST /campaigns/:id/actions/send`.
    public nonisolated func sendInvitation(campaignID: Int,
                                           _ invitation: ScreenInvitation) async throws -> ScreenInvitationResult {
        try Self.requirePositiveID(campaignID, kind: "campaign")
        let invitation = try Self.validatedInvitation(invitation)
        return try await send(ScreenInvitationResult.self,
                              method: "POST",
                              path: "/campaigns/\(campaignID)/actions/send",
                              body: invitation)
    }

    // MARK: Test sessions

    /// One page of test sessions. `GET /tests`. All filters are optional; the API
    /// reports `pagination.nextStart`/`hasMoreItems` for paging, or use
    /// `listAllTests` to follow every page.
    public nonisolated func listTests(campaignID: Int? = nil,
                                      product: String? = nil,
                                      candidateEmail: String? = nil,
                                      from: Int? = nil,
                                      until: Int? = nil,
                                      start: Int? = nil,
                                      limit: Int? = nil) async throws -> ScreenTestsPage {
        if let campaignID {
            try Self.requirePositiveID(campaignID, kind: "campaign")
        }
        let filters = try Self.normalizedListFilters(product: product, candidateEmail: candidateEmail)
        if let start {
            try Self.requirePaginationStart(start)
        }
        if let limit, !(1 ... Self.maximumPageSize).contains(limit) {
            throw CoderPadError.decode("Screen pagination limit must be between 1 and \(Self.maximumPageSize).")
        }
        try Self.validateTimeRange(from: from, until: until)
        var query: [URLQueryItem] = []
        if let campaignID {
            query.append(URLQueryItem(name: "campaignId", value: String(campaignID)))
        }
        if let product = filters.product {
            query.append(URLQueryItem(name: "product", value: product))
        }
        if let candidateEmail = filters.candidateEmail {
            query.append(URLQueryItem(name: "candidateEmail", value: candidateEmail))
        }
        if let from {
            query.append(URLQueryItem(name: "from", value: String(from)))
        }
        if let until {
            query.append(URLQueryItem(name: "to", value: String(until)))
        }
        if let start {
            query.append(URLQueryItem(name: "start", value: String(start)))
        }
        if let limit {
            query.append(URLQueryItem(name: "limit", value: String(limit)))
        }
        return try await get(ScreenTestsPage.self, path: "/tests", query: query)
    }

    /// A single test session's status and (once finished) report. `GET /tests/:id`.
    /// `withCommunityStats` adds the report's community score distribution.
    public nonisolated func getTest(id: Int, withCommunityStats: Bool = false) async throws -> ScreenTestSession {
        try Self.requirePositiveID(id, kind: "test")
        let query = withCommunityStats ? [URLQueryItem(name: "withCommunityStats", value: "true")] : []
        return try await get(ScreenTestSession.self, path: "/tests/\(id)", query: query)
    }

    /// Cancels a not-yet-started test invitation. `POST /tests/:id/actions/cancel`.
    public nonisolated func cancelTest(id: Int) async throws {
        try Self.requirePositiveID(id, kind: "test")
        try await sendNoContent(method: "POST", path: "/tests/\(id)/actions/cancel")
    }

    /// Resends the invitation email for a test. `POST /tests/:id/actions/resend`.
    public nonisolated func resendTest(id: Int) async throws {
        try Self.requirePositiveID(id, kind: "test")
        try await sendNoContent(method: "POST", path: "/tests/\(id)/actions/resend")
    }

    /// Deletes a test session. `DELETE /tests/:id`.
    public nonisolated func deleteTest(id: Int) async throws {
        try Self.requirePositiveID(id, kind: "test")
        try await sendNoContent(method: "DELETE", path: "/tests/\(id)")
    }

    /// The candidate's report as a PDF. `GET /tests/:id/report`. Returns the raw
    /// PDF bytes; `reportType` selects the report variant when the API offers more
    /// than one.
    public nonisolated func testReport(id: Int,
                                       reportType: ScreenReportType? = nil,
                                       anonymous: Bool? = nil,
                                       includeRank: Bool? = nil,
                                       includeComparativeScore: Bool? = nil) async throws -> Data {
        try Self.requirePositiveID(id, kind: "test")
        var query: [URLQueryItem] = []
        if let reportType {
            query.append(URLQueryItem(name: "report_type", value: reportType.rawValue))
        }
        if let anonymous {
            query.append(URLQueryItem(name: "anonymous", value: String(anonymous)))
        }
        if let includeRank {
            query.append(URLQueryItem(name: "include_rank", value: String(includeRank)))
        }
        if let includeComparativeScore {
            query.append(URLQueryItem(name: "include_comparative_score", value: String(includeComparativeScore)))
        }
        let request = try authorizedRequest(path: "/tests/\(id)/report", method: "GET",
                                            query: query, accept: "application/pdf")
        let (data, response) = try await reportData(for: request)
        // A 2xx that isn't actually a PDF (an HTML error page, an empty body) must
        // not be opened or saved as a candidate report (#859).
        let contentType = response.value(forHTTPHeaderField: "Content-Type") ?? ""
        let mediaType = contentType.split(separator: ";", maxSplits: 1).first?
            .trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard mediaType == "application/pdf", ScreenReportFiles.isLikelyPDF(data) else {
            throw CoderPadError.decode("The report response was not a PDF.")
        }

        return data
    }

    // MARK: - Transport

    /// Builds an authorized request, attaching the `API-Key` header that every
    /// Screen endpoint requires.
    nonisolated func authorizedRequest(
        path: String,
        method: String,
        query: [URLQueryItem] = [],
        accept: String = "application/json"
    ) throws -> URLRequest {
        guard !apiKey.isEmpty else { throw CoderPadError.missingAPIKey }
        guard Self.isAllowedBaseURL(baseURL) else {
            throw CoderPadError.decode("Screen base URL must be a credential-free HTTPS origin.")
        }

        var components = URLComponents(url: baseURL.appending(path: Self.apiPrefix + path),
                                       resolvingAgainstBaseURL: false)
        if !query.isEmpty {
            components?.queryItems = query
        }
        guard let url = components?.url else { throw CoderPadError.http(0, "Invalid URL") }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue(apiKey, forHTTPHeaderField: "API-Key")
        request.setValue(accept, forHTTPHeaderField: "Accept")
        return request
    }

    public nonisolated func get<T: Decodable>(
        _ type: T.Type,
        path: String,
        query: [URLQueryItem] = []
    ) async throws -> T {
        let request = try authorizedRequest(path: path, method: "GET", query: query)
        return try await decode(type, from: data(for: request).0)
    }

    private nonisolated func send<T: Decodable>(_ type: T.Type,
                                                method: String,
                                                path: String,
                                                body: some Encodable) async throws -> T {
        var request = try authorizedRequest(path: path, method: method)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try encode(body)
        return try await decode(type, from: data(for: request).0)
    }

    /// For the 204-No-Content actions (cancel/resend/delete/webhook). An optional
    /// JSON body covers `POST /webhook`, whose body is a bare URL string.
    public nonisolated func sendNoContent(
        method: String,
        path: String,
        body: (some Encodable)? = String?.none
    ) async throws {
        var request = try authorizedRequest(path: path, method: method)
        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try encode(body)
        }
        _ = try await data(for: request)
    }

    /// One coder each for every Screen call, rather than one per request/response.
    ///
    /// Screen carries no ISO-8601 dates (timestamps are epoch-millisecond ints), so the
    /// default configuration suffices and nothing here mutates their options — which is
    /// what made the per-call allocation pure waste on every request, including each
    /// page of `listAllTests` (#2115). Both types are safe to use concurrently as long
    /// as they are only read, so `nonisolated(unsafe)` covers the off-main decodes,
    /// matching `WidgetPadSnapshot`'s shared pair.
    private nonisolated static let decoder = JSONDecoder()
    private nonisolated static let encoder = JSONEncoder()

    nonisolated func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        do {
            return try Self.decoder.decode(type, from: data)
        } catch {
            throw CoderPadError.decode(String(describing: error))
        }
    }

    private nonisolated func encode(_ body: some Encodable) throws -> Data {
        try Self.encoder.encode(body)
    }
}

private extension ScreenClient {
    public nonisolated static func validateTimeRange(from: Int?, until: Int?) throws {
        if let from {
            guard (ScreenEpochMilliseconds.earliest ... ScreenEpochMilliseconds.latest).contains(from) else {
                throw CoderPadError.decode(
                    "Screen time filters must be epoch milliseconds between 2000 and 2100."
                )
            }
        }
        if let until {
            guard (ScreenEpochMilliseconds.earliest ... ScreenEpochMilliseconds.latest).contains(until) else {
                throw CoderPadError.decode(
                    "Screen time filters must be epoch milliseconds between 2000 and 2100."
                )
            }
        }
        guard from.map({ start in until.map { start <= $0 } ?? true }) ?? true else {
            throw CoderPadError.decode("Screen time filter start must not be later than its end.")
        }
    }

    public nonisolated static func requirePositiveID(_ id: Int, kind: String) throws {
        guard (1 ... maximumScreenID).contains(id) else {
            throw CoderPadError.decode("Screen \(kind) ID must be a positive int32.")
        }
    }

    public nonisolated static func requirePaginationStart(_ start: Int) throws {
        guard start >= 0 else {
            throw CoderPadError.decode("Screen pagination start must not be negative.")
        }
        // Keep start + maximumPageSize representable so mock/page math cannot trap (#211).
        guard start <= Int.max - maximumPageSize else {
            throw CoderPadError.decode("Screen pagination start is too large.")
        }
    }

    public nonisolated static func normalizedFilter(
        _ raw: String?,
        name: String,
        maximumLength: Int
    ) throws -> String? {
        guard let raw else { return nil }

        let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty, value.count <= maximumLength,
              !value.unicodeScalars.contains(where: { scalar in
                  let category = scalar.properties.generalCategory
                  return category == .control || category == .format
              })
        else {
            throw CoderPadError.decode("Screen \(name) filter is invalid or too long.")
        }

        return value
    }

    public nonisolated static func normalizedListFilters(product: String?, candidateEmail: String?) throws
        -> (product: String?, candidateEmail: String?) {
        let product = try normalizedProductFilter(product)
        let candidateEmail = try normalizedFilter(
            candidateEmail, name: "candidate email", maximumLength: maximumEmailFilterLength
        ).map(EmailValidation.normalized)
        if let candidateEmail, !EmailValidation.isPlausibleAddress(candidateEmail) {
            throw CoderPadError.decode("Screen candidate email filter is invalid or too long.")
        }
        return (product, candidateEmail)
    }

    /// Trims and lowercases a product filter, then requires one of the documented
    /// wire values (`screen`, `map`). `nil` means "no product filter" (#104).
    public nonisolated static func normalizedProductFilter(_ raw: String?) throws -> String? {
        guard let product = try normalizedFilter(
            raw, name: "product", maximumLength: maximumProductFilterLength
        ) else {
            return nil
        }

        let normalized = product.lowercased()
        guard allowedProductFilters.contains(normalized) else {
            throw CoderPadError.decode(
                "Screen product filter must be one of: \(allowedProductFilters.sorted().joined(separator: ", "))."
            )
        }
        return normalized
    }

    /// Normalizes invitation emails, enforces the candidate-name length limit, and
    /// rejects contradictory delivery options before transport (#105, #108, #197).
    public nonisolated static func validatedInvitation(_ invitation: ScreenInvitation) throws -> ScreenInvitation {
        var invitation = invitation
        invitation.candidateEmail = try validatedInvitationEmail(
            invitation.candidateEmail, kind: "candidate"
        )
        invitation.recruiterEmail = try validatedInvitationEmail(
            invitation.recruiterEmail, kind: "recruiter"
        )
        if let name = invitation.candidateName, name.count > maximumCandidateNameLength {
            throw CoderPadError.decode(
                "Screen candidate name must be at most \(maximumCandidateNameLength) characters."
            )
        }
        if invitation.sendInvitationEmail == true, invitation.candidateEmail == nil {
            throw CoderPadError.decode(
                "Screen send_invitation_email requires a candidate email."
            )
        }
        return invitation
    }

    private nonisolated static func validatedInvitationEmail(_ raw: String?, kind: String) throws -> String? {
        guard let raw else { return nil }
        let normalized = try normalizedFilter(
            raw, name: "\(kind) email", maximumLength: maximumEmailFilterLength
        ).map(EmailValidation.normalized)
        guard let normalized, EmailValidation.isPlausibleAddress(normalized) else {
            throw CoderPadError.decode("Screen \(kind) email is invalid or too long.")
        }
        return normalized
    }
}
