//
//  ChartView+ChartViewProtocol.swift
//  telegram-charts
//
//  Created by Roman Aliyev on 3/25/19.
//  Copyright © 2019 Roman Aliyev. All rights reserved.
//

import UIKit

extension ChartView: ChartViewProtocol {
    var primaryCanvasSize: CGSize {
        return self.primaryCanvas.bounds.size
    }
    
    var secondaryCanvasSize: CGSize {
        return self.secondaryCanvas.bounds.size
    }
    
    func transformPrimaryCanvasShapes(animated: Bool) {
        guard let chartModel = chartModel else {
            return
        }
        
        if !animated {
            CATransaction.begin()
            CATransaction.setDisableActions(true)
        }
        
        for row in 0..<chartModel.legendItems.count {
            primaryCanvas.shapeLayers[row].setAffineTransform(chartModel.primaryCanvasTransform)
            let legendItemModel = chartModel.legendItems[row]
            primaryCanvas.shapeLayers[row].opacity = legendItemModel.isChecked ? 1 : 0
            primaryCanvas.shapeLayers[row].lineWidth = (1 / chartModel.primaryCanvasTransform.a + 1 / chartModel.primaryCanvasTransform.d) / 2
        }
        
        if !animated {
            CATransaction.commit()
        }
    }
    
    func transformSecondaryCanvasShapes(animated: Bool) {
        guard let chartModel = chartModel else {
            return
        }
        
        if !animated {
            CATransaction.begin()
            CATransaction.setDisableActions(true)
        }
        
        for row in 0..<chartModel.legendItems.count {
            secondaryCanvas.shapeLayers[row].setAffineTransform(chartModel.secondaryCanvasTransform)
            let legendItemModel = chartModel.legendItems[row]
            secondaryCanvas.shapeLayers[row].opacity = legendItemModel.isChecked ? 1 : 0
            secondaryCanvas.shapeLayers[row].lineWidth = (1 / chartModel.secondaryCanvasTransform.a + 1 / chartModel.secondaryCanvasTransform.d) / 2
        }
        
        if !animated {
            CATransaction.commit()
        }
    }
}
