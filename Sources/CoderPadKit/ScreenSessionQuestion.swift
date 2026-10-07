import Foundation

/// A question entry preserving either the list's integer identity or a detailed UUID identity.
public nonisolated enum ScreenSessionQuestion: Decodable, Hashable, Sendable {
    case summary(ScreenTestQuestion)
    case detailed(ScreenDetailedQuestion)

    private enum CodingKeys: String, CodingKey { case id }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if (try? container.decode(Int.self, forKey: .id)) != nil {
            self = .summary(try ScreenTestQuestion(from: decoder))
        } else {
            self = .detailed(try ScreenDetailedQuestion(from: decoder))
        }
    }
}
