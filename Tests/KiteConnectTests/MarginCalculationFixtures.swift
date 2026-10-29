//
//  MarginCalculationFixtures.swift
//  swiftkiteconnect
//
//  Created by Ankit Goyal on 29/10/2026.

import Foundation
import KiteConnect
import Testing

let calculationMarginJSON = #"""
{
  "status": "success",
  "data": [
    {
      "type": "equity",
      "tradingsymbol": "INFY",
      "exchange": "NSE",
      "span": 0,
      "exposure": 0,
      "option_premium": 0,
      "additional": 0,
      "bo": 0,
      "cash": 0,
      "var": 1498,
      "pnl": {
        "realised": 0,
        "unrealised": 0
      },
      "leverage": 1,
      "charges": {
        "transaction_tax": 1.498,
        "transaction_tax_type": "stt",
        "exchange_turnover_charge": 0.051681,
        "sebi_turnover_charge": 0.001498,
        "brokerage": 0.01,
        "stamp_duty": 0.22,
        "gst": {
          "igst": 0.011372219999999999,
          "cgst": 0,
          "sgst": 0,
          "total": 0.011372219999999999
        },
        "total": 1.79255122
      },
      "total": 1498
    }
  ]
}
"""#

func calculationOrder() throws -> KiteMarginOrder {
    try KiteMarginOrder(
        instrument: KiteInstrumentIdentity(exchange: .nse, tradingSymbol: "INFY"),
        transactionType: .buy, variety: .regular, product: .cnc, orderType: .market, quantity: 1,
    )
}

let calculationBasketJSON = #"""
{
  "status": "success",
  "data": {
    "initial": {
      "type": "",
      "tradingsymbol": "",
      "exchange": "",
      "span": 66832.5,
      "exposure": 29151.225000000002,
      "option_premium": 521.25,
      "additional": 0,
      "bo": 0,
      "cash": 0,
      "var": 0,
      "pnl": {
        "realised": 0,
        "unrealised": 0
      },
      "leverage": 0,
      "charges": {
        "transaction_tax": 0,
        "transaction_tax_type": "",
        "exchange_turnover_charge": 0,
        "sebi_turnover_charge": 0,
        "brokerage": 0,
        "stamp_duty": 0,
        "gst": {
          "igst": 0,
          "cgst": 0,
          "sgst": 0,
          "total": 0
        },
        "total": 0
      },
      "total": 96504.975
    },
    "final": {
      "type": "",
      "tradingsymbol": "",
      "exchange": "",
      "span": 7788.000000000007,
      "exposure": 29151.225000000002,
      "option_premium": -2152.5,
      "additional": 0,
      "bo": 0,
      "cash": 0,
      "var": 0,
      "pnl": {
        "realised": 0,
        "unrealised": 0
      },
      "leverage": 0,
      "charges": {
        "transaction_tax": 0,
        "transaction_tax_type": "",
        "exchange_turnover_charge": 0,
        "sebi_turnover_charge": 0,
        "brokerage": 0,
        "stamp_duty": 0,
        "gst": {
          "igst": 0,
          "cgst": 0,
          "sgst": 0,
          "total": 0
        },
        "total": 0
      },
      "total": 34786.725000000006
    },
    "orders": [
      {
        "type": "equity",
        "tradingsymbol": "NIFTY23JUL20600CE",
        "exchange": "NFO",
        "span": 66832.5,
        "exposure": 29151.225000000002,
        "option_premium": 0,
        "additional": 0,
        "bo": 0,
        "cash": 0,
        "var": 0,
        "pnl": {
          "realised": 0,
          "unrealised": 0
        },
        "leverage": 1,
        "charges": {
          "transaction_tax": 1.67109375,
          "transaction_tax_type": "stt",
          "exchange_turnover_charge": 1.336875,
          "sebi_turnover_charge": 0.00267375,
          "brokerage": 20,
          "stamp_duty": 0,
          "gst": {
            "igst": 3.8411187749999995,
            "cgst": 0,
            "sgst": 0,
            "total": 3.8411187749999995
          },
          "total": 26.851761274999998
        },
        "total": 95983.725
      },
      {
        "type": "equity",
        "tradingsymbol": "NIFTY23JUL20700CE",
        "exchange": "NFO",
        "span": 0,
        "exposure": 0,
        "option_premium": 521.25,
        "additional": 0,
        "bo": 0,
        "cash": 0,
        "var": 0,
        "pnl": {
          "realised": 0,
          "unrealised": 0
        },
        "leverage": 1,
        "charges": {
          "transaction_tax": 0,
          "transaction_tax_type": "stt",
          "exchange_turnover_charge": 0.260625,
          "sebi_turnover_charge": 0.00052125,
          "brokerage": 20,
          "stamp_duty": 0,
          "gst": {
            "igst": 3.6470063249999995,
            "cgst": 0,
            "sgst": 0,
            "total": 3.6470063249999995
          },
          "total": 23.908152575
        },
        "total": 521.25
      }
    ],
    "charges": {
      "transaction_tax": 0,
      "transaction_tax_type": "",
      "exchange_turnover_charge": 0,
      "sebi_turnover_charge": 0.003195,
      "brokerage": 40,
      "stamp_duty": 0,
      "gst": {
        "igst": 0,
        "cgst": 0,
        "sgst": 0,
        "total": 0
      },
      "total": 0
    }
  }
}
"""#

let calculationChargesJSON = #"""
{
  "status": "success",
  "data": [
    {
      "transaction_type": "BUY",
      "tradingsymbol": "SBIN",
      "exchange": "NSE",
      "variety": "regular",
      "product": "CNC",
      "order_type": "MARKET",
      "quantity": 1,
      "price": 560,
      "charges": {
        "transaction_tax": 0.56,
        "transaction_tax_type": "stt",
        "exchange_turnover_charge": 0.01876,
        "sebi_turnover_charge": 0.00056,
        "brokerage": 0,
        "stamp_duty": 0,
        "gst": {
          "igst": 0.0033767999999999997,
          "cgst": 0,
          "sgst": 0,
          "total": 0.0033767999999999997
        },
        "total": 0.5826968
      }
    },
    {
      "transaction_type": "SELL",
      "tradingsymbol": "GOLDPETAL23JULFUT",
      "exchange": "MCX",
      "variety": "regular",
      "product": "NRML",
      "order_type": "LIMIT",
      "quantity": 1,
      "price": 5862,
      "charges": {
        "transaction_tax": 0.5862,
        "transaction_tax_type": "ctt",
        "exchange_turnover_charge": 0.152412,
        "sebi_turnover_charge": 0.005862,
        "brokerage": 1.7586,
        "stamp_duty": 0,
        "gst": {
          "igst": 0.34503732,
          "cgst": 0,
          "sgst": 0,
          "total": 0.34503732
        },
        "total": 2.84811132
      }
    },
    {
      "transaction_type": "BUY",
      "tradingsymbol": "NIFTY2371317900PE",
      "exchange": "NFO",
      "variety": "regular",
      "product": "NRML",
      "order_type": "LIMIT",
      "quantity": 100,
      "price": 1.5,
      "charges": {
        "transaction_tax": 0,
        "transaction_tax_type": "stt",
        "exchange_turnover_charge": 0.07575,
        "sebi_turnover_charge": 0.00015,
        "brokerage": 20,
        "stamp_duty": 0,
        "gst": {
          "igst": 3.613527,
          "cgst": 0,
          "sgst": 0,
          "total": 3.613527
        },
        "total": 23.689427000000002
      }
    }
  ]
}
"""#

enum CalculationOperation: CaseIterable, Sendable {
    case orders, basket, compactOrders, compactBasket, charges
    func run(_ client: KiteClient) async throws {
        switch self {
        case .orders: _ = try await client.orderMargins([calculationOrder()])
        case .basket: _ = try await client.basketMargins([calculationOrder()])
        case .compactOrders: _ = try await client.compactOrderMargins([calculationOrder()])
        case .compactBasket: _ = try await client.compactBasketMargins([calculationOrder()])
        case .charges:
            _ = try await client.orderCharges([
                KiteChargeOrder(
                    orderID: "hypothetical", instrument: calculationOrder().instrument,
                    transactionType: .buy, product: .cnc, orderType: .market, quantity: 1, averagePrice: 560,
                ),
            ])
        }
    }

    var response: String {
        switch self {
        case .orders, .compactOrders: calculationMarginJSON
        case .basket, .compactBasket: calculationBasketJSON
        case .charges: calculationChargesJSON
        }
    }
}

let requiredCalculationPaths = [
    "type", "exchange", "tradingsymbol", "span", "exposure", "option_premium", "additional",
    "bo", "cash", "var", "pnl", "pnl.realised", "pnl.unrealised", "leverage", "total", "charges",
    "charges.transaction_tax", "charges.transaction_tax_type", "charges.exchange_turnover_charge",
    "charges.sebi_turnover_charge", "charges.brokerage", "charges.stamp_duty", "charges.total",
    "charges.gst", "charges.gst.igst", "charges.gst.cgst", "charges.gst.sgst", "charges.gst.total",
]

func corruptCalculation(_ object: [String: Any], path: [String], corruption: String)
    -> [String: Any]
{
    var result = object
    let key = path[0]
    if path.count > 1 {
        result[key] = corruptCalculation(
            result[key] as! [String: Any], path: Array(path.dropFirst()), corruption: corruption,
        )
    } else {
        switch corruption {
        case "missing": result.removeValue(forKey: key)
        case "null": result[key] = NSNull()
        default: result[key] = ["invalid"]
        }
    }
    return result
}
