import 'security_label.dart';

/**
 * A security type in SecDart.
 */
abstract class SecurityType {
  SecurityType();

  SecurityLabel get label;
  SecurityType stampLabel(SecurityLabel label);

  SecurityType downgradeLabel(SecurityLabel label);
}

abstract class InterfaceSecurityType extends SecurityType {
  SecurityFunctionType getMethodSecurityType(String methodName);
  SecurityType getFieldSecurityType(String fieldName);
}

abstract class SecurityFunctionType extends SecurityType {
  SecurityLabel get beginLabel;
  List<SecurityType> get argumentTypes;
  SecurityType get returnType;
  SecurityLabel get endLabel;
}
