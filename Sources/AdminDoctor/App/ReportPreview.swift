import AdminDoctorCore
import Foundation

struct ReportPreview: Identifiable {
    enum ContentKind {
        case text
        case html
        case pdf
    }

    let id = UUID()
    let format: ReportFormat
    let title: String
    let kind: ContentKind
    let text: String
    let data: Data
}
