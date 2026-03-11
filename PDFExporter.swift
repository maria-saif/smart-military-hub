import Foundation
import PDFKit
import UIKit

private struct AssignmentRow {
    let date: Date
    let shiftName: String
    let soldierName: String
    let rank: String
    let unit: String
}

final class PDFExporter {

    func makePDF(schedule: ScheduleResult,
                 soldiers: [Soldier],
                 templates: [ShiftTemplate]) -> URL? {

        let rows = buildRows(schedule: schedule, soldiers: soldiers, templates: templates)
            .sorted { a, b in
                if a.date != b.date { return a.date < b.date }
                if a.unit != b.unit { return a.unit < b.unit }
                return a.soldierName < b.soldierName
            }

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("schedule-\(Int(Date().timeIntervalSince1970)).pdf")

        let pageRect = CGRect(x: 0, y: 0, width: 595, height: 842) // A4
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect, format: pdfFormat())

        do {
            try renderer.writePDF(to: url) { ctx in
                var pageIndex = 0
                var rowIndex = 0

                while rowIndex < rows.count || pageIndex == 0 {
                    ctx.beginPage()
                    pageIndex += 1

                    let headerBottomY = drawHeader(in: ctx.cgContext, page: pageRect, pageIndex: pageIndex)

                    let tableFrame = CGRect(x: pageRect.minX + 36,
                                            y: headerBottomY + 16,
                                            width: pageRect.width - 72,
                                            height: pageRect.height - (headerBottomY + 16) - 72)

                    rowIndex = drawTable(rows: rows, startAt: rowIndex, in: ctx.cgContext, frame: tableFrame)

                    drawFooter(in: ctx.cgContext, page: pageRect, pageNumber: pageIndex)
                }
            }
            return url
        } catch {
            print("PDF export error:", error)
            return nil
        }
    }

    private func buildRows(schedule: ScheduleResult,
                           soldiers: [Soldier],
                           templates: [ShiftTemplate]) -> [AssignmentRow] {

        let soldiersDict:  [UUID: Soldier]       = Dictionary(uniqueKeysWithValues: soldiers.map { ($0.id, $0) })
        let templatesDict: [UUID: ShiftTemplate] = Dictionary(uniqueKeysWithValues: templates.map { ($0.id, $0) })

        return schedule.assignments.map { a in
            let soldier  = soldiersDict[a.soldierId]
            let template = templatesDict[a.templateId]

            let name = soldier?.name ?? "غير معروف"
            let rank = soldier?.rank ?? "—"
            let unit = soldier?.unit ?? "—"
            let shift = template?.name ?? "شفت"

            return AssignmentRow(date: a.date,
                                 shiftName: shift,
                                 soldierName: name,
                                 rank: rank,
                                 unit: unit)
        }
    }
}

private extension PDFExporter {

    func pdfFormat() -> UIGraphicsPDFRendererFormat {
        let fmt = UIGraphicsPDFRendererFormat()
        let meta: [CFString: Any] = [
            kCGPDFContextTitle: "جدول المناوبات",
            kCGPDFContextAuthor: "Smart Military Hub",
            kCGPDFContextCreator: "Smart Military Hub – Scheduler"
        ]
        fmt.documentInfo = meta as [String: Any]
        return fmt
    }

    @discardableResult
    func drawHeader(in cg: CGContext, page: CGRect, pageIndex: Int) -> CGFloat {
        let headerRect = CGRect(x: page.minX, y: page.minY, width: page.width, height: 96)

        cg.saveGState()
        cg.setFillColor(UIColor(white: 0.97, alpha: 1).cgColor)
        cg.fill(headerRect)
        cg.restoreGState()

        if let logo = UIImage(named: "RoyalArmyLogo") {
            let targetH: CGFloat = 48
            let ratio = logo.size.width / logo.size.height
            let logoRect = CGRect(x: page.maxX - 36 - targetH * ratio,
                                  y: headerRect.minY + 24,
                                  width: targetH * ratio,
                                  height: targetH)
            logo.draw(in: logoRect)
        } else {
            drawText("Smart Military Hub",
                     at: CGPoint(x: page.maxX - 36, y: headerRect.minY + 36),
                     align: .right,
                     font: .systemFont(ofSize: 12, weight: .semibold),
                     color: .darkGray)
        }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ar")
        formatter.dateStyle = .medium
        let today = formatter.string(from: Date())

        drawText("جدول المناوبات",
                 at: CGPoint(x: 36, y: headerRect.minY + 26),
                 align: .left,
                 font: .systemFont(ofSize: 20, weight: .bold),
                 color: .black)

        drawText("تاريخ الإنشاء: \(today)",
                 at: CGPoint(x: 36, y: headerRect.minY + 58),
                 align: .left,
                 font: .systemFont(ofSize: 12),
                 color: .gray)

        cg.saveGState()
        cg.setStrokeColor(UIColor(white: 0.85, alpha: 1).cgColor)
        cg.setLineWidth(1)
        cg.move(to: CGPoint(x: 36, y: headerRect.maxY - 0.5))
        cg.addLine(to: CGPoint(x: page.maxX - 36, y: headerRect.maxY - 0.5))
        cg.strokePath()
        cg.restoreGState()

        return headerRect.maxY
    }

    func drawFooter(in cg: CGContext, page: CGRect, pageNumber: Int) {
        let footerY = page.maxY - 40

        cg.saveGState()
        cg.setStrokeColor(UIColor(white: 0.85, alpha: 1).cgColor)
        cg.setLineWidth(1)
        cg.move(to: CGPoint(x: 36, y: footerY))
        cg.addLine(to: CGPoint(x: page.maxX - 36, y: footerY))
        cg.strokePath()
        cg.restoreGState()

        drawText("صفحة \(pageNumber)",
                 at: CGPoint(x: page.midX, y: footerY + 12),
                 align: .center,
                 font: .systemFont(ofSize: 11),
                 color: .darkGray)
    }

    @discardableResult
    func drawTable(rows: [AssignmentRow], startAt: Int, in cg: CGContext, frame: CGRect) -> Int {
        let colWidths: [CGFloat] = [0.18, 0.20, 0.28, 0.14, 0.20].map { $0 * frame.width }
        let headerTitles = ["التاريخ", "الشفت", "الجندي", "الرتبة", "الوحدة"]

        let rowHeight: CGFloat = 26
        let headerHeight: CGFloat = 30
        let maxRows = Int(floor((frame.height - headerHeight) / rowHeight))
        let end = min(rows.count, startAt + maxRows)

        var x = frame.minX
        var y = frame.minY

        drawTableHeader(titles: headerTitles, widths: colWidths,
                        at: CGPoint(x: x, y: y), height: headerHeight, in: cg)
        y += headerHeight

        let dateFmt = DateFormatter()
        dateFmt.locale = Locale(identifier: "ar")
        dateFmt.dateStyle = .medium

        for i in startAt..<end {
            let r = rows[i]
            let cells = [
                dateFmt.string(from: r.date),
                r.shiftName,
                r.soldierName,
                r.rank,
                r.unit
            ]

            var cx = x
            for (colIdx, text) in cells.enumerated() {
                let rect = CGRect(x: cx, y: y, width: colWidths[colIdx], height: rowHeight)
                drawCell(text: text, in: rect, rtl: true, isOdd: (i % 2 == 1), context: cg)
                cx += colWidths[colIdx]
            }

            cg.saveGState()
            cg.setStrokeColor(UIColor(white: 0.88, alpha: 1).cgColor)
            cg.setLineWidth(0.5)
            cg.move(to: CGPoint(x: x, y: y + rowHeight))
            cg.addLine(to: CGPoint(x: x + colWidths.reduce(0, +), y: y + rowHeight))
            cg.strokePath()
            cg.restoreGState()

            y += rowHeight
        }

        return end
    }

    func drawTableHeader(titles: [String], widths: [CGFloat], at origin: CGPoint, height: CGFloat, in cg: CGContext) {
        var x = origin.x
        let y = origin.y

        let headerRect = CGRect(x: x, y: y, width: widths.reduce(0, +), height: height)

        cg.saveGState()
        cg.setFillColor(UIColor(red: 0.90, green: 0.97, blue: 0.92, alpha: 1).cgColor)
        cg.fill(headerRect)
        cg.restoreGState()

        cg.saveGState()
        cg.setStrokeColor(UIColor(red: 0.65, green: 0.85, blue: 0.72, alpha: 1).cgColor)
        cg.setLineWidth(1)
        cg.stroke(headerRect)
        cg.restoreGState()

        for (i, t) in titles.enumerated() {
            let rect = CGRect(x: x + 6, y: y, width: widths[i] - 12, height: height)
            drawText(t, in: rect, align: .right,
                     font: .systemFont(ofSize: 12, weight: .semibold), color: .black)
            x += widths[i]
        }
    }

    func drawCell(text: String, in rect: CGRect, rtl: Bool, isOdd: Bool, context cg: CGContext) {
        if isOdd {
            cg.saveGState()
            cg.setFillColor(UIColor(white: 0.98, alpha: 1).cgColor)
            cg.fill(rect)
            cg.restoreGState()
        }
        let inner = rect.insetBy(dx: 6, dy: 4)
        drawText(text, in: inner, align: rtl ? .right : .left,
                 font: .systemFont(ofSize: 11), color: .black)
    }

    func drawText(_ text: String, in rect: CGRect, align: NSTextAlignment, font: UIFont, color: UIColor) {
        let style = NSMutableParagraphStyle()
        style.alignment = align
        style.baseWritingDirection = .rightToLeft
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color,
            .paragraphStyle: style
        ]
        (text as NSString).draw(in: rect, withAttributes: attrs)
    }

    func drawText(_ text: String, at point: CGPoint, align: NSTextAlignment, font: UIFont, color: UIColor) {
        let size = (text as NSString).size(withAttributes: [.font: font])
        var pt = point
        switch align {
        case .left: break
        case .center: pt.x -= size.width / 2
        case .right: pt.x -= size.width
        default: break
        }
        drawText(text, in: CGRect(origin: pt, size: size), align: align, font: font, color: color)
    }
}
