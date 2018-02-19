import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:analyzer/src/dart/element/element.dart';
import 'package:secdart_analyzer/security_label.dart';
import 'package:secdart_analyzer/security_type.dart';
import 'package:secdart_analyzer/src/annotations/parser.dart';
import 'package:secdart_analyzer/src/error_collector.dart';
import 'package:secdart_analyzer/src/security_type.dart';

abstract class ElementAnnotationParser {
  /**
   * A general representation of the lattice this parser parses
   */
  Lattice get lattice;

  /**
   * Returns the security type associated to this element. We assume that
   * the element has a metadata property.
   */
  SecurityType fromIdentifierDeclaration(Element element, DartType type);
}

class ElementAnnotationParserImpl extends ElementAnnotationParser {
  SecAnnotationParser _parser;
  ElementAnnotationParserImpl([bool intervalMode = false]) {
    _parser = new FlatLatticeParser(new ErrorCollector(), intervalMode);
  }

  Lattice get lattice => _parser.lattice;

  SecurityType fromDartType(DartType type, SecurityLabel label) {
    if (type is InterfaceType) {
      return securityTypeFromClass(type, label);
    }
    //if it is a function type is should be defined as type alias
    if (type is FunctionType) {
      if (_isDeclaredAsTypeAlias(type)) {
        return _fromFunctionTypeAlias(type.element.enclosingElement);
      }
      //in this case we do not have type annotations
      SecurityType returnType = fromDartType(type.returnType, label);
      return new SecurityFunctionTypeImpl(
          lattice.dynamic,
          type.parameters
              .map((t) => fromIdentifierDeclaration(t, t.type))
              .toList(),
          returnType,
          label);
    }
    return new DynamicSecurityType(label);
  }

  /**
   * Given an element (with annotations) (eg. parameter, variable declaration)
   * returns its security type.
   */
  SecurityType fromIdentifierDeclaration(Element element, DartType type) {
    //get the label ascribed via annotations
    var label = _getSecurityLabel(element, element.metadata);
    //case where the parameter is a function type
    if (type is FunctionType) {
      if (_isDeclaredAsTypeAlias(type)) {
        return _fromFunctionTypeAlias(type.element.enclosingElement);
      }
      //the function signature is inlined (this is the case where [element]
      //correspond to a [ParameterElement]
      else {
        SecurityType returnType = fromDartType(type.returnType, label);
        return new SecurityFunctionTypeImpl(
            //TODO: find a way to specify labels for functions types
            lattice.dynamic,
            type.parameters
                .map((t) => fromIdentifierDeclaration(t, t.type))
                .toList(),
            returnType,
            label);
      }
    }
    if (type.element is ClassElement) {
      return securityTypeFromClass(type, label);
    }
    //it must be a function alias then
    return new DynamicSecurityType(label);
  }

  SecurityFunctionType getFunctionSecType(Iterable<Annotation> metadataList,
      List<ParameterElement> parameters, DartType returnType) {
    //label are dynamic by default
    var returnLabel = lattice.dynamic;
    var beginLabel = lattice.dynamic;
    var endLabel = lattice.dynamic;
    if (metadataList != null) {
      var latentAnnotations =
          metadataList.where((a) => a.name.name == FUNCTION_LATENT_LABEL);

      if (latentAnnotations.length == 1) {
        Annotation securityFunctionAnnotation = latentAnnotations.first;
        var funAnnotationLabel =
            _parser.parseFunctionLabel(securityFunctionAnnotation);
        beginLabel = funAnnotationLabel.beginLabel;
        endLabel = funAnnotationLabel.endLabel;
      }

      var returnAnnotations = metadataList.where((a) => _parser.isLabel(a));
      if (returnAnnotations.length == 1) {
        returnLabel = _parser.parseLabel(returnAnnotations.first);
      }
    }
    var parameterSecTypes = new List<SecurityType>();
    for (ParameterElement p in parameters) {
      parameterSecTypes.add(fromIdentifierDeclaration(p, p.type));
    }
    var returnSecurityType = fromDartType(returnType, returnLabel);
    return new SecurityFunctionTypeImpl(
        beginLabel, parameterSecTypes, returnSecurityType, endLabel);
  }

  ClassSecurityInfo securityInfoFromClass(InterfaceType classType) {
    Map<String, SecurityFunctionType> methodTypes = {};
    classType.methods.forEach((mElement) {
      var metadataList = mElement.metadata
          .map((m) => (m as ElementAnnotationImpl).annotationAst);
      methodTypes.putIfAbsent(
          mElement.name,
          () => getFunctionSecType(
              metadataList, mElement.parameters, mElement.returnType));
    });
    Map<String, SecurityType> accessors = {};
    classType.accessors.forEach((property) {
      //it means the getter or setter was generated from a field
      var metadata;
      if (property.isSynthetic) {
        metadata = property.variable.metadata;
      } else {
        metadata = property.metadata;
      }
      var dartType = null;
      if (property.isGetter) {
        dartType = property.returnType;
      }
      //property.isSetter
      else {
        dartType = property.type.parameters.first.type;
      }
      accessors.putIfAbsent(property.name,
          () => fromDartType(dartType, _getSecurityLabel(property, metadata)));
    });

    return new ClassSecurityInfo(methodTypes, accessors);
  }

  SecurityType securityTypeForFunctionElement(FunctionElement element) {
    var metadataList =
        element.metadata.map((m) => (m as ElementAnnotationImpl).annotationAst);
    return getFunctionSecType(
        metadataList, element.parameters, element.returnType);
  }

  SecurityType securityTypeFromClass(
      InterfaceType interfaceType, SecurityLabel label) {
    //if the class was not defined with security concerns in mind.
    if (!_elementIsDefinedInSecDartLibrary(interfaceType.element)) {
      //TODO: Get either a parametric version for the security type or
      //the unknown security type
      return new InterfaceSecurityTypeImpl.forExternalClass(
          label, interfaceType);
    }
    return new InterfaceSecurityTypeImpl(
        label, interfaceType, securityInfoFromClass(interfaceType));
  }

  bool _elementIsDefinedInSecDartLibrary(Element element) {
    return element.library.imports
            .where((import) => import.uri != null
                ? import.uri.contains("secdart.dart")
                : false)
            .length !=
        0;
  }

  SecurityFunctionType _fromFunctionTypeAlias(
      FunctionTypeAliasElement element) {
    if (!_elementIsDefinedInSecDartLibrary(element)) {
      return new SecurityFunctionTypeImpl(
          lattice.top,
          element.parameters
              .map((p) => fromDartType(p.type, lattice.top))
              .toList(),
          fromDartType(element.returnType, lattice.bottom),
          lattice.bottom);
    }
    //take the security annotation from the typedef
    return getFunctionSecType(
        element.metadata.map((m) => (m as ElementAnnotationImpl).annotationAst),
        element.parameters,
        element.returnType);
  }

  SecurityLabel _getSecurityLabel(
      dynamic element, List<ElementAnnotation> metadata) {
    var secLabelAnnotations = metadata
        .map((e) => (e as ElementAnnotationImpl).annotationAst)
        .where((x) => _parser.isLabel(x));
    var label = _parser.lattice.dynamic;
    if (secLabelAnnotations.length == 1) {
      label = _parser.parseLabel(secLabelAnnotations.first);
    }
    return label;
  }

  bool _isDeclaredAsTypeAlias(FunctionType type) {
    return type.element.enclosingElement is FunctionTypeAliasElement;
  }

  SecurityLabel parseLiteralLabel(String value) {
    return _parser.parseString(value);
  }
}
