//
//  ExportService.swift
//  ProgressPic
//
//  Created by Claude
//

import Foundation
import SwiftUI
import SwiftData

/// Service for exporting measurement data and journey reports
enum ExportService {
    
    // MARK: - CSV Export
    
    /// Export measurement entries to CSV format
    /// - Parameters:
    ///   - entries: Array of measurement entries to export
    ///   - journey: Optional journey context for metadata
    /// - Returns: CSV data ready to be saved or shared
    static func exportMeasurementsToCSV(entries: [MeasurementEntry], journey: Journey? = nil) -> Data? {
        // Sort entries by date (oldest first)
        let sortedEntries = entries.sorted { $0.date < $1.date }
        
        guard !sortedEntries.isEmpty else {
            AppConstants.Log.data.warning("No measurements to export")
            return nil
        }
        
        // Build CSV header
        var csvString = "Date,Time,Measurement Type,Value,Unit,Label\n"
        
        // Add metadata comment if journey is provided
        if let journey = journey {
            csvString = "# Journey: \(journey.name)\n" +
                       "# Export Date: \(Date().formatted(date: .long, time: .standard))\n" +
                       "# Total Measurements: \(sortedEntries.count)\n\n" +
                       csvString
        }
        
        // Create date formatters
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .none
        
        let timeFormatter = DateFormatter()
        timeFormatter.dateStyle = .none
        timeFormatter.timeStyle = .short
        
        // Add each measurement entry
        for entry in sortedEntries {
            let date = dateFormatter.string(from: entry.date)
            let time = timeFormatter.string(from: entry.date)
            let type = entry.type.title
            let value = String(format: "%.1f", entry.value)
            let unit = entry.unit.rawValue
            let label = entry.label?.replacingOccurrences(of: ",", with: ";") ?? "" // Escape commas
            
            csvString += "\(date),\(time),\(type),\(value),\(unit),\(label)\n"
        }
        
        return csvString.data(using: .utf8)
    }
    
    /// Export all measurements grouped by type to CSV
    /// - Parameters:
    ///   - entries: Array of measurement entries
    ///   - journey: Journey context
    /// - Returns: CSV data with measurements organized by type
    static func exportMeasurementsByTypeToCSV(entries: [MeasurementEntry], journey: Journey) -> Data? {
        let sortedEntries = entries.sorted { $0.date < $1.date }
        
        guard !sortedEntries.isEmpty else {
            AppConstants.Log.data.warning("No measurements to export")
            return nil
        }
        
        // Group measurements by type
        let groupedByType = Dictionary(grouping: sortedEntries) { $0.type }
        
        // Get all unique dates
        let uniqueDates = Set(sortedEntries.map {
            Calendar.current.startOfDay(for: $0.date)
        }).sorted()
        
        // Get all measurement types present
        let types = groupedByType.keys.sorted { $0.title < $1.title }
        
        // Build CSV header
        var csvString = "# Journey: \(journey.name)\n"
        csvString += "# Export Date: \(Date().formatted(date: .long, time: .standard))\n\n"
        csvString += "Date"
        
        for type in types {
            csvString += ",\(type.title)"
        }
        csvString += "\n"
        
        // Date formatter
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .none
        
        // Add data rows
        for date in uniqueDates {
            csvString += dateFormatter.string(from: date)
            
            for type in types {
                // Find measurement for this date and type
                let measurement = groupedByType[type]?.first {
                    Calendar.current.isDate($0.date, inSameDayAs: date)
                }
                
                if let measurement = measurement {
                    csvString += ",\(String(format: "%.1f", measurement.value))"
                } else {
                    csvString += "," // Empty cell
                }
            }
            
            csvString += "\n"
        }
        
        return csvString.data(using: .utf8)
    }
    
    // MARK: - File Sharing Helpers
    
    /// Generate a filename for CSV export
    /// - Parameters:
    ///   - journey: Journey context
    ///   - type: Type of export (e.g., "measurements", "summary")
    /// - Returns: Formatted filename
    static func generateCSVFilename(journey: Journey?, type: String = "measurements") -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateString = dateFormatter.string(from: Date())
        
        if let journey = journey {
            let journeyName = journey.name.replacingOccurrences(of: " ", with: "_")
            return "ProgressPic_\(journeyName)_\(type)_\(dateString).csv"
        } else {
            return "ProgressPic_\(type)_\(dateString).csv"
        }
    }
    
    /// Create a temporary file URL for sharing
    /// - Parameters:
    ///   - data: Data to write
    ///   - filename: Name of the file
    /// - Returns: URL to the temporary file
    static func createTemporaryFile(data: Data, filename: String) throws -> URL {
        let tempDirectory = FileManager.default.temporaryDirectory
        let fileURL = tempDirectory.appendingPathComponent(filename)
        
        try data.write(to: fileURL, options: .atomic)
        
        return fileURL
    }
}

// MARK: - View Extension for Sharing

// Note: ShareSheet is defined in ShareUtilities.swift and takes a URL parameter

