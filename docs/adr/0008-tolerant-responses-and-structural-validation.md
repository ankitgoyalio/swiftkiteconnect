# Preserve unfamiliar response values and validate request structure

Response models will expose known typed cases while preserving unfamiliar server values as an unknown case carrying the original string. Additional JSON fields will be ignored; missing or malformed required fields will fail decoding clearly. This allows server additions without silently accepting corrupt required data.

The SDK will validate documented structural request requirements locally. Changing broker and exchange business rules, including current tradability and available margin, remain Kite's responsibility rather than being duplicated in the SDK.
