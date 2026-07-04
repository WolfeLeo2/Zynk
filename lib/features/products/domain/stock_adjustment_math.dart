/// Pure stock-adjustment math shared by the inventory-adjustment screen and
/// the group batch-update sheet, so their add/subtract/set logic can never
/// drift and is unit-testable without any widget or DB.
///
/// Modes are the string literals the UI already uses: 'add', 'subtract', 'set'.
library;

/// The resulting stock level after applying [amount] to [current] in [mode].
/// 'set' ignores [current] (it's an absolute target); unknown modes are
/// treated as 'set' so a bad string can never silently add/subtract.
num resolveStockTarget(String mode, num current, num amount) {
  switch (mode) {
    case 'add':
      return current + amount;
    case 'subtract':
      return current - amount;
    default: // 'set'
      return amount;
  }
}

/// The signed change to persist as a stock_adjustment (target − current).
/// For 'add' this is +amount, for 'subtract' −amount, and for 'set' it's
/// whatever delta lands the branch on the absolute target.
num resolveStockDelta(String mode, num current, num amount) =>
    resolveStockTarget(mode, current, amount) - current;
