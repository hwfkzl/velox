/// 货币类型枚举
enum CurrencyType {
  rub, // 俄罗斯卢布 (默认)
  usd, // 美元
  eur, // 欧元
  cny, // 人民币
  twd, // 新台币
}

/// 货币配置
class CurrencyConfig {
  final String symbol;
  final String code;
  final String name;
  final int decimalDigits;
  final bool symbolBefore; // 符号在金额前还是后

  const CurrencyConfig({
    required this.symbol,
    required this.code,
    required this.name,
    this.decimalDigits = 2,
    this.symbolBefore = true,
  });
}

/// 货币工具类
class CurrencyUtils {
  CurrencyUtils._();

  /// 货币配置映射
  static const Map<CurrencyType, CurrencyConfig> _currencies = {
    CurrencyType.rub: CurrencyConfig(
      symbol: '₽',
      code: 'RUB',
      name: 'Российский рубль',
      decimalDigits: 0, // 卢布通常不显示小数
      symbolBefore: false,
    ),
    CurrencyType.usd: CurrencyConfig(
      symbol: '\$',
      code: 'USD',
      name: 'US Dollar',
      decimalDigits: 2,
      symbolBefore: true,
    ),
    CurrencyType.eur: CurrencyConfig(
      symbol: '€',
      code: 'EUR',
      name: 'Euro',
      decimalDigits: 2,
      symbolBefore: true,
    ),
    CurrencyType.cny: CurrencyConfig(
      symbol: '¥',
      code: 'CNY',
      name: '人民币',
      decimalDigits: 2,
      symbolBefore: true,
    ),
    CurrencyType.twd: CurrencyConfig(
      symbol: 'NT\$',
      code: 'TWD',
      name: '新台幣',
      decimalDigits: 0,
      symbolBefore: true,
    ),
  };

  /// 默认货币
  static CurrencyType defaultCurrency = CurrencyType.cny;

  /// 获取货币配置
  static CurrencyConfig getConfig(CurrencyType type) {
    return _currencies[type] ?? _currencies[CurrencyType.rub]!;
  }

  /// 格式化价格 (分为单位转换为元)
  /// [priceInCents] 分为单位的价格
  /// [currency] 货币类型，默认使用 defaultCurrency
  static String formatPrice(int priceInCents, {CurrencyType? currency}) {
    final type = currency ?? defaultCurrency;
    final config = getConfig(type);

    // 转换为元
    final priceInUnits = priceInCents / 100;

    // 格式化数字
    String formatted;
    if (config.decimalDigits == 0) {
      formatted = priceInUnits.round().toString();
    } else {
      formatted = priceInUnits.toStringAsFixed(config.decimalDigits);
    }

    // 添加千位分隔符
    formatted = _addThousandsSeparator(formatted);

    // 组合符号和金额
    if (config.symbolBefore) {
      return '${config.symbol}$formatted';
    } else {
      return '$formatted ${config.symbol}';
    }
  }

  /// 格式化价格 (已经是元为单位)
  static String formatPriceFromUnits(double price, {CurrencyType? currency}) {
    return formatPrice((price * 100).round(), currency: currency);
  }

  /// 添加千位分隔符
  static String _addThousandsSeparator(String number) {
    final parts = number.split('.');
    final intPart = parts[0];
    final decPart = parts.length > 1 ? '.${parts[1]}' : '';

    final buffer = StringBuffer();
    int count = 0;
    for (int i = intPart.length - 1; i >= 0; i--) {
      if (count > 0 && count % 3 == 0) {
        buffer.write(' ');
      }
      buffer.write(intPart[i]);
      count++;
    }

    return buffer.toString().split('').reversed.join() + decPart;
  }

  /// 获取所有支持的货币
  static List<CurrencyType> get supportedCurrencies => CurrencyType.values;

  /// 根据语言代码获取推荐货币
  static CurrencyType getCurrencyForLocale(String languageCode) {
    switch (languageCode) {
      case 'ru':
        return CurrencyType.rub;
      case 'en':
        return CurrencyType.usd;
      case 'zh':
        return CurrencyType.cny; // 简体中文默认人民币
      default:
        return CurrencyType.cny;
    }
  }
}
