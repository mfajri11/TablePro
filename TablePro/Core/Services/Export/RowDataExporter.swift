//
//  RowDataExporter.swift
//  TablePro
//

import Foundation

/// Utility for converting row data to various text formats for clipboard copy.
internal struct RowDataExporter {
    
    enum ExportFormat {
        case sqlInsert
        case csv
        case json
    }
    
    /// Convert rows to the specified format
    static func export(
        columns: [String],
        rows: [[String?]],
        format: ExportFormat,
        tableName: String? = nil,
        primaryKeyColumn: String? = nil,
        quoteIdentifier: ((String) -> String)? = nil,
        escapeStringLiteral: ((String) -> String)? = nil
    ) -> String {
        switch format {
        case .sqlInsert:
            guard let tableName = tableName else { return "" }
            let converter = SQLRowToStatementConverter(
                tableName: tableName,
                columns: columns,
                primaryKeyColumn: primaryKeyColumn,
                databaseType: .mysql, // Fallback, will use dialect-based quoting if provided
                quoteIdentifier: quoteIdentifier,
                escapeStringLiteral: escapeStringLiteral
            )
            return converter.generateInserts(rows: rows)
            
        case .csv:
            return toCSV(columns: columns, rows: rows)
            
        case .json:
            return toJSON(columns: columns, rows: rows)
        }
    }
    
    private static func toCSV(columns: [String], rows: [[String?]]) -> String {
        var lines: [String] = []
        // Header
        lines.append(columns.map { escapeCSV($0) }.joined(separator: ","))
        // Rows
        for row in rows {
            lines.append(row.map { escapeCSV($0 ?? "NULL") }.joined(separator: ","))
        }
        return lines.joined(separator: "\n")
    }
    
    private static func toJSON(columns: [String], rows: [[String?]]) -> String {
        var jsonRows: [[String: String?]] = []
        for row in rows {
            var dict: [String: String?] = [:]
            for (i, column) in columns.enumerated() {
                if i < row.count {
                    dict[column] = row[i]
                }
            }
            jsonRows.append(dict)
        }
        
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        if let data = try? encoder.encode(jsonRows), let string = String(data: data, encoding: .utf8) {
            return string
        }
        return "[]"
    }
    
    private static func escapeCSV(_ value: String) -> String {
        if value.contains(",") || value.contains("\"") || value.contains("\n") || value.contains("\r") {
            let escaped = value.replacingOccurrences(of: "\"", with: "\"\"")
            return "\"\(escaped)\""
        }
        return value
    }
}
