# Distinguish instrument identity and temporal values

Separate Swift types will distinguish an instrument's exchange/trading-symbol identity from its numeric instrument token. Persistent watchlists use exchange and trading symbol; subscriptions and historical requests use the token required by Kite, since tokens may be reused after derivative expiry.

Expiry dates will use a date-only type, while timestamps representing instants will use `Date`. Explicit timestamp offsets will determine the instant; offsetless fields will use a configurable trading timezone defaulting to `Asia/Kolkata`, never an implicit device timezone. The default for offsetless fields is an SDK policy rather than a claim that all such fields have an explicitly documented timezone.
