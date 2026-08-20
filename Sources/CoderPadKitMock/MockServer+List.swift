//
//  MockServer+List.swift
//  CoderPadKitMock
//
//  Sort and fixed-size pagination for Interview list endpoints. The live API pages
//  at 50 records and accepts `sort=field,direction` (created_at / updated_at).
//

import Foundation

nonisolated enum MockList {
    /// Documented Interview list page size. The API exposes no way to change it.
    static let pageSize = 50

    /// Fields the live Interview list endpoints accept in `sort`.
    private static let supportedSortFields: Set<String> = ["created_at", "updated_at"]

    /// Applies `sort` (default `created_at,desc`) or returns a 400 for unsupported values.
    static func sorted(
        _ items: [[String: Any]],
        query: [String: String]
    ) -> ([[String: Any]]?, (Int, Data)?) {
        let raw = query["sort"] ?? "created_at,desc"
        let parts = raw.split(separator: ",", omittingEmptySubsequences: false).map(String.init)
        guard parts.count == 2 else {
            return (nil, invalidSortResponse)
        }
        let field = parts[0]
        let direction = parts[1]
        guard supportedSortFields.contains(field),
              direction == "asc" || direction == "desc" else {
            return (nil, invalidSortResponse)
        }
        let ascending = direction == "asc"
        let sorted = items.sorted { lhs, rhs in
            let left = lhs[field] as? String ?? ""
            let right = rhs[field] as? String ?? ""
            return ascending ? left < right : left > right
        }
        return (sorted, nil)
    }

    /// One page of `items` under `collectionKey`, with `total` and a cursor `next_page`.
    static func page(
        _ items: [[String: Any]],
        query: [String: String],
        path: String,
        collectionKey: String
    ) -> (Int, Data) {
        let page = max(query["page"].flatMap(Int.init) ?? 1, 1)
        let total = items.count
        let start = (page - 1) * pageSize
        let end = min(start + pageSize, total)
        let window = start < total ? Array(items[start ..< end]) : []

        var response: [String: Any] = [
            "status": "OK",
            collectionKey: window,
            "total": total,
            "next_page": NSNull()
        ]
        if end < total, let next = nextPageURL(path: path, query: query, page: page + 1) {
            response["next_page"] = next
        }
        return MockResponses.ok(response)
    }

    private static var invalidSortResponse: (Int, Data) {
        (400, MockResponses.jsonString([
            "status": "error",
            "message": "invalid sort"
        ]))
    }

    /// Absolute `next_page` URL matching the live API's cursor shape.
    private static func nextPageURL(path: String, query: [String: String], page: Int) -> String? {
        var components = URLComponents()
        components.scheme = "https"
        components.host = MockServer.host
        components.path = path.hasPrefix("/") ? path : "/\(path)"
        var items: [URLQueryItem] = []
        if let sort = query["sort"] {
            items.append(URLQueryItem(name: "sort", value: sort))
        }
        items.append(URLQueryItem(name: "page", value: String(page)))
        components.queryItems = items
        return components.url?.absoluteString
    }
}

nonisolated extension MockResponses {
    /// Sort then page a pad/question collection, or surface a sort 400.
    static func listed(
        _ items: [[String: Any]],
        query: [String: String],
        path: String,
        key: String
    ) -> (Int, Data) {
        let (sorted, error) = MockList.sorted(items, query: query)
        if let error { return error }
        return MockList.page(sorted ?? [], query: query, path: path, collectionKey: key)
    }

    /// A JSON object body, or `nil` when the body is missing, empty, malformed, or not
    /// an object. Shared by pad create/update so both reject the same bad payloads.
    static func jsonObject(from body: Data?) -> [String: Any]? {
        guard let body, !body.isEmpty else { return nil }
        guard let object = try? JSONSerialization.jsonObject(with: body) else { return nil }
        return object as? [String: Any]
    }

    static var invalidJSONBodyResponse: (Int, Data) {
        (400, jsonString(["status": "error", "message": "invalid JSON body"]))
    }
}
