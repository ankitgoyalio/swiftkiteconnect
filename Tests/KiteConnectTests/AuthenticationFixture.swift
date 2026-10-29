//
//  AuthenticationFixture.swift
//  swiftkiteconnect
//
//  Created by Ankit Goyal on 27/10/2026.

/// Official user.html token-exchange example, 2026-10-27 snapshot. Placeholder values only.
let authenticationJSON = #"""
{
  "status": "success",
  "data": {
    "user_type": "individual",
    "email": "XXXXXX",
    "user_name": "Kite Connect",
    "user_shortname": "Connect",
    "broker": "ZERODHA",
    "exchanges": [
      "NSE",
      "NFO",
      "BFO",
      "CDS",
      "BSE",
      "MCX",
      "BCD",
      "MF"
    ],
    "products": [
      "CNC",
      "NRML",
      "MIS",
      "BO",
      "CO"
    ],
    "order_types": [
      "MARKET",
      "LIMIT",
      "SL",
      "SL-M"
    ],
    "avatar_url": "abc",
    "user_id": "XX0000",
    "api_key": "XXXXXX",
    "access_token": "XXXXXX",
    "public_token": "XXXXXXXX",
    "enctoken": "XXXXXX",
    "refresh_token": "",
    "silo": "",
    "login_time": "2021-01-01 16:15:14",
    "meta": {
      "demat_consent": "physical"
    }
  }
}
"""#
