/// Text symbol constants used across screens, written as Unicode escapes so
/// they are immune to file-encoding corruption (the "â" mojibake that results
/// from a UTF-8 multi-byte char being decoded as Latin-1/CP-1252: `â‚¹`, `â†’`,
/// `â€”`, `Ã—`, `Â·`, `â€¦`). Always render these via the constants below.
library;

/// ₹ — Indian rupee sign.
const String kRupee = '\u20B9';

/// → — rightward arrow.
const String kArrow = '\u2192';

/// – — en dash.
const String kEnDash = '\u2013';

/// — — em dash.
const String kEmDash = '\u2014';

/// · — middle dot / interpunct.
const String kMiddleDot = '\u00B7';

/// × — multiplication sign.
const String kMultiply = '\u00D7';

/// … — ellipsis.
const String kEllipsis = '\u2026';

/// • — bullet point.
const String kBullet = '\u2022';