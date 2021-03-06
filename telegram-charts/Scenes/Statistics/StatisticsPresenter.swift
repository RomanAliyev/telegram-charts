import UIKit
import CoreGraphics

protocol StatisticsPresenterProtocol {
    func present(chartObjects: [ChartObject])
    func present(chartObject: ChartObject)
    func scale(primaryCanvasShapesBy id: String, animated: Bool)
    func scale(secondaryCanvasShapesBy id: String, animated: Bool)
    func presentAlert(about error: StatisticsControllerError)
}

class StatisticsPresenter {
    let routeToAlert: RouteToAlertProtocol
    weak var statisticsView: StatisticsViewProtocol!
    
    init(
        routeToAlert: RouteToAlertProtocol,
        statisticsView: StatisticsViewProtocol
    ) {
        self.routeToAlert = routeToAlert
        self.statisticsView = statisticsView
    }
}

extension StatisticsPresenter: StatisticsPresenterProtocol {
    func presentAlert(about error: StatisticsControllerError) {
        switch error {
        case .loadDataError(let innerError):
            switch innerError {
            case ChartDataError.fileCouldNotBeLocated(let fileName):
                routeToAlert.presentAlert(
                    "Unable to load the chart data",
                    message: "\"\(fileName)\" could not be located"
                )
            case ChartDataError.urlCanNotBeRead(let url):
                routeToAlert.presentAlert(
                    "Unable to load the chart data",
                    message: "Can't read \"\(url)\""
                )
            case ChartDataError.unsupportedDataFormat(let url):
                routeToAlert.presentAlert(
                    "Unable to load the chart data",
                    message: "Unsupported format of \"\(url)\""
                )
            default:
                routeToAlert.presentAlert(
                    "Unable to load the chart data",
                    message: "The application encountered an unexpected error"
                )
            }
        }
    }
    
    func present(chartObjects: [ChartObject]) {
        for chartObjectIndex in 0..<chartObjects.count {
            let chartObject = chartObjects[chartObjectIndex]
            let chart = StatisticsViewModel.Chart(
                id: chartObject.id,
                title: chartObject.name,
                legendItems: chartObject.chartData.map {
                    return StatisticsViewModel.LegendItem(
                        id: $0.id,
                        title: $0.name ?? $0.id,
                        color: UIColor(hexColor: $0.color ?? "") ?? .gray,
                        chartId: chartObject.id
                    )
                }
            )
            chart.selectorRightOffset = 0
            chart.selectorLeftOffset = UIScreen.main.bounds.width - 150
            statisticsView.viewModel.charts.append(chart)
        }
        statisticsView.updateAllSections()
    }
    
    func present(chartObject: ChartObject) {
        let viewModel = statisticsView.viewModel
        guard let section = (viewModel.charts.firstIndex { $0.id == chartObject.id }) else {
            return
        }
        guard let chartView = statisticsView.chartView(at: section) else {
            return
        }
        let primaryCanvasSize = chartView.primaryCanvasSize
        let secondaryCanvasSize = chartView.secondaryCanvasSize
        guard primaryCanvasSize != .zero && secondaryCanvasSize != .zero else {
            return
        }
        let numberOfSamples = chartObject.xData.dataSize
        guard numberOfSamples > 0 else {
            return
        }
        let xDataMin = CGFloat(chartObject.xData.minValue)
        let xDataMax = CGFloat(chartObject.xData.maxValue)
        let xPointsPerSample = primaryCanvasSize.width / (xDataMax - xDataMin)
        let yDataMin = CGFloat(chartObject.chartData.min(by: { $0.yData.minValue < $1.yData.minValue })?.yData.minValue ?? 0)
        let yDataMax = CGFloat(chartObject.chartData.max(by: { $0.yData.maxValue < $1.yData.maxValue })?.yData.maxValue ?? 0)
        var yPointsPerSample = primaryCanvasSize.height / (yDataMax - yDataMin)
        var primaryCanvasPaths = [CGPath]()
        var secondaryCanvasPaths = [CGPath]()
        var t = CGAffineTransform(scaleX: xPointsPerSample, y: -yPointsPerSample)
            .translatedBy(x: -xDataMin, y: -yDataMin - primaryCanvasSize.height / yPointsPerSample)
        
        for row in 0..<chartObject.chartData.count {
            let path = CGMutablePath()
            path.move(to: CGPoint(x: Double(chartObject.xData.data[0]), y: chartObject.chartData[row].yData.data[0]), transform: t)
            for sampleIndex in 0..<numberOfSamples {
                let x = Double(chartObject.xData.data[sampleIndex])
                let y = chartObject.chartData[row].yData.data[sampleIndex]
                path.addLine(to: CGPoint(x: Double(x), y: y), transform: t)
            }
            primaryCanvasPaths.append(path)
        }
        
        yPointsPerSample = secondaryCanvasSize.height / (yDataMax - yDataMin)
        t = CGAffineTransform(scaleX: xPointsPerSample, y: -yPointsPerSample)
            .translatedBy(x: -xDataMin, y: -yDataMin - secondaryCanvasSize.height / yPointsPerSample)
        
        for row in 0..<chartObject.chartData.count {
            let path = CGMutablePath()
            path.move(to: CGPoint(x: Double(chartObject.xData.data[0]), y: chartObject.chartData[row].yData.data[0]), transform: t)
            for sampleIndex in 0..<numberOfSamples {
                let x = Double(chartObject.xData.data[sampleIndex])
                let y = chartObject.chartData[row].yData.data[sampleIndex]
                path.addLine(to: CGPoint(x: Double(x), y: y), transform: t)
            }
            secondaryCanvasPaths.append(path)
        }
        viewModel.charts[section].primaryCanvasPaths = primaryCanvasPaths
        viewModel.charts[section].secondaryCanvasPaths = secondaryCanvasPaths
        statisticsView.update(chartViewShapesAt: section)
    }
    
    func scale(primaryCanvasShapesBy id: String, animated: Bool) {
        let viewModel = statisticsView.viewModel
        guard let section = (viewModel.charts.firstIndex { $0.id == id }) else {
            return
        }
        guard let chartView = statisticsView.chartView(at: section) else {
            return
        }
        let primaryCanvasSize = chartView.primaryCanvasSize
        guard primaryCanvasSize != .zero else {
            return
        }
        let chartModel = viewModel.charts[section]
        var primaryCanvasShapeBoundingBox = CGRect.null
        for row in 0..<chartModel.legendItems.count {
            guard chartModel.legendItems[row].isChecked else {
                continue
            }
            if let boundingBox = chartModel.primaryCanvasPaths?[row].boundingBox(
                minX: 0,
                maxX: primaryCanvasSize.width
            ) {
                primaryCanvasShapeBoundingBox = primaryCanvasShapeBoundingBox.union(boundingBox)
            }
        }
        
        chartModel.primaryCanvasTransform = CGAffineTransform(
            scaleX: 1,
            y: primaryCanvasSize.height / primaryCanvasShapeBoundingBox.height
        ).translatedBy(
            x: 0,
            y: -primaryCanvasShapeBoundingBox.minY
        )
        chartView.transformPrimaryCanvasShapes(animated: animated)
    }
    
    func scale(secondaryCanvasShapesBy id: String, animated: Bool) {
        let viewModel = statisticsView.viewModel
        guard let section = (viewModel.charts.firstIndex { $0.id == id }) else {
            return
        }
        guard let chartView = statisticsView.chartView(at: section) else {
            return
        }
        let secondaryCanvasSize = chartView.secondaryCanvasSize
        guard secondaryCanvasSize != .zero else {
            return
        }
        let chartModel = viewModel.charts[section]
        var secondaryCanvasShapeBoundingBox = CGRect.null
        for row in 0..<chartModel.legendItems.count {
            guard chartModel.legendItems[row].isChecked else {
                continue
            }
            if let boundingBox = chartModel.secondaryCanvasPaths?[row].boundingBox(
                minX: chartModel.selectorLeftOffset,
                maxX: secondaryCanvasSize.width - chartModel.selectorRightOffset
            ) {
                secondaryCanvasShapeBoundingBox = secondaryCanvasShapeBoundingBox.union(boundingBox)
            }
        }
        
        chartModel.secondaryCanvasTransform = CGAffineTransform(
            scaleX: secondaryCanvasSize.width / secondaryCanvasShapeBoundingBox.width,
            y: secondaryCanvasSize.height / secondaryCanvasShapeBoundingBox.height
        ).translatedBy(
            x: -secondaryCanvasShapeBoundingBox.minX,
            y: -secondaryCanvasShapeBoundingBox.minY
        )
        
        chartView.transformSecondaryCanvasShapes(animated: animated)
    }
}
