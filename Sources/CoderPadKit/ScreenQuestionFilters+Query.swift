import Foundation

nonisolated extension ScreenQuestionFilters {
    var queryItems: [URLQueryItem] {
        var items: [URLQueryItem] = []
        if let type { items.append(URLQueryItem(name: "type", value: type)) }
        if let durationSecondsMin {
            items.append(URLQueryItem(name: "duration_seconds_min", value: String(durationSecondsMin)))
        }
        if let durationSecondsMax {
            items.append(URLQueryItem(name: "duration_seconds_max", value: String(durationSecondsMax)))
        }
        if let difficulty { items.append(URLQueryItem(name: "difficulty", value: difficulty.rawValue)) }
        if let domain { items.append(URLQueryItem(name: "domain", value: domain)) }
        if let skill { items.append(URLQueryItem(name: "skill", value: skill)) }
        if let programmingLanguage {
            items.append(URLQueryItem(name: "programming_language", value: programmingLanguage))
        }
        if let fromCoderPadQuestionBank {
            items.append(URLQueryItem(name: "from_coderpad_question_bank", value: String(fromCoderPadQuestionBank)))
        }
        if let product { items.append(URLQueryItem(name: "product", value: product.rawValue)) }
        if let sort { items.append(URLQueryItem(name: "sort", value: sort.rawValue)) }
        if let order { items.append(URLQueryItem(name: "order", value: order.rawValue)) }
        return items
    }
}
