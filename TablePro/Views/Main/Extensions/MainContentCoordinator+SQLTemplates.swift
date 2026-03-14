//
//  MainContentCoordinator+SQLTemplates.swift
//  TablePro
//
//  SQL template generation for table context menu.
//

import Foundation
import TableProPluginKit

extension MainContentCoordinator {
    enum SQLTemplateType {
        case select
        case insert
        case update
        case delete
    }

    /// Generate a SQL template for the given table and type, and show it in a preview modal.
    func generateSQLTemplate(tableName: String, type: SQLTemplateType) {
        Task {
            // Fetch columns asynchronously using the schema provider.
            // This may fetch from database if not cached.
            let columns = await schemaProvider.getColumns(for: tableName)

            // Build the SQL string
            let sql = buildTemplate(tableName: tableName, columns: columns, type: type)

            // Show in preview sheet on main actor
            await MainActor.run {
                activeSheet = .sqlPreview(statements: [sql])
            }
        }
    }

    private func buildTemplate(tableName: String, columns: [ColumnInfo], type: SQLTemplateType) -> String {
        let driver = DatabaseManager.shared.driver(for: connectionId)
        
        // Quoting function for identifiers (tables/columns)
        let quote: (String) -> String = { name in
            driver?.quoteIdentifier(name) ?? "\"\(name.replacingOccurrences(of: "\"", with: "\"\""))\""
        }
        
        let quotedTable = quote(tableName)
        let colNames = columns.map { quote($0.name) }
        
        switch type {
        case .select:
            let colList = colNames.isEmpty ? "*" : colNames.joined(separator: ", ")
            return "SELECT \(colList)\nFROM \(quotedTable)\nLIMIT 1000;"
            
        case .insert:
            if colNames.isEmpty {
                return "INSERT INTO \(quotedTable) (column1, column2)\nVALUES (value1, value2);"
            }
            let colList = colNames.joined(separator: ", ")
            let valList = columns.map { _ in "?" }.joined(separator: ", ")
            return "INSERT INTO \(quotedTable) (\(colList))\nVALUES (\(valList));"
            
        case .update:
            if colNames.isEmpty {
                return "UPDATE \(quotedTable)\nSET column1 = value1\nWHERE condition;"
            }
            let setClause = colNames.map { "\($0) = ?" }.joined(separator: ", ")
            return "UPDATE \(quotedTable)\nSET \(setClause)\nWHERE condition;"
            
        case .delete:
            return "DELETE FROM \(quotedTable)\nWHERE condition;"
        }
    }
}
