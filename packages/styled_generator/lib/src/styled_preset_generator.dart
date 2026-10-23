import 'dart:async';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/nullability_suffix.dart';
import 'package:build/build.dart';
import 'package:source_gen/source_gen.dart';
import 'package:styled_annotation/styled_annotation.dart';

class StyledPresetGenerator extends GeneratorForAnnotation<StyledPreset> {
  const StyledPresetGenerator();

  @override
  FutureOr<String> generateForAnnotatedElement(
    Element element,
    ConstantReader annotation,
    BuildStep buildStep,
  ) {
    if (element is! ClassElement) {
      throw InvalidGenerationSourceError(
        '@StyledPreset can only be applied to classes.',
        element: element,
      );
    }

    final rawName = annotation.peek('name')?.stringValue;
    final className = (rawName != null && rawName.isNotEmpty)
        ? rawName
        : _deriveClassName(element.name!);

    final generateVariantsEnum =
        annotation.peek('generateVariantsEnum')?.boolValue ?? true;
    final mergeBase = annotation.peek('mergeBase')?.boolValue ?? true;

    final variantEnumName = _deriveVariantEnumName(className);

    // Identify methods
    MethodElement? baseMethod;
    final variantMethods = <_VariantMethodInfo>[];

    const variantChecker = TypeChecker.any([
      TypeChecker.typeNamedLiterally('Variant', inPackage: 'styled_annotation'),
      TypeChecker.typeNamedLiterally('Variant', inPackage: 'styled'),
      TypeChecker.typeNamed(Variant),
    ]);

    const responsiveChecker = TypeChecker.any([
      TypeChecker.typeNamedLiterally('Responsive', inPackage: 'styled_annotation'),
      TypeChecker.typeNamedLiterally('Responsive', inPackage: 'styled'),
      TypeChecker.typeNamed(Responsive),
    ]);

    MethodElement? findMethod(String? name) {
      if (name == null) return null;
      for (final m in element.methods) {
        if (m.name == name) return m;
      }
      return null;
    }

    String? findConventionMethod(String candidate) {
      for (final m in element.methods) {
        if (m.name == candidate || m.name == '_$candidate') {
          return m.name;
        }
      }
      return null;
    }

    // Collect method names referenced as responsive delegates so they are not treated as top-level variants
    final responsiveDelegates = <String>{};
    for (final method in element.methods) {
      if (!method.isStatic) continue;
      final respAnn = responsiveChecker.firstAnnotationOf(method);
      if (respAnn != null) {
        final reader = ConstantReader(respAnn);
        final mobile = reader.peek('mobile')?.stringValue ?? findConventionMethod('${method.name}Mobile');
        final tablet = reader.peek('tablet')?.stringValue ?? findConventionMethod('${method.name}Tablet');
        final desktop = reader.peek('desktop')?.stringValue ?? findConventionMethod('${method.name}Desktop');
        if (mobile != null) responsiveDelegates.add(mobile);
        if (tablet != null) responsiveDelegates.add(tablet);
        if (desktop != null) responsiveDelegates.add(desktop);
      }
    }

    for (final method in element.methods) {
      if (!method.isStatic) continue;

      final variantAnnotation = variantChecker.firstAnnotationOf(method);
      final hasVariantAnnotation = variantAnnotation != null;

      if (!hasVariantAnnotation && responsiveDelegates.contains(method.name)) {
        continue;
      }

      if ((method.name?.startsWith('_') ?? false) && !hasVariantAnnotation) {
        continue;
      }

      if (method.name == 'base' && !hasVariantAnnotation) {
        baseMethod = method;
        continue;
      }

      final returnType = method.returnType.getDisplayString();
      final returnsStyle = returnType.contains('Style');

      if (hasVariantAnnotation || returnsStyle) {
        final reader = variantAnnotation != null ? ConstantReader(variantAnnotation) : null;
        final isDefault = reader?.peek('isDefault')?.boolValue ?? false;
        final aliases = reader
                ?.peek('aliases')
                ?.listValue
                .map((e) => e.toStringValue()!)
                .toList() ??
            <String>[];

        _ResponsiveInfo? responsiveInfo;
        final respAnnotation = responsiveChecker.firstAnnotationOf(method);
        if (respAnnotation != null) {
          final respReader = ConstantReader(respAnnotation);
          final mobileName = respReader.peek('mobile')?.stringValue ?? findConventionMethod('${method.name}Mobile');
          final tabletName = respReader.peek('tablet')?.stringValue ?? findConventionMethod('${method.name}Tablet');
          final desktopName = respReader.peek('desktop')?.stringValue ?? findConventionMethod('${method.name}Desktop');
          final attachStates = respReader.peek('attachStates')?.boolValue ?? false;

          final mobileMethod = findMethod(mobileName);
          if (mobileName != null && mobileMethod == null) {
            throw InvalidGenerationSourceError(
              'Method "$mobileName" referenced in @Responsive on "${method.name}" was not found in ${element.name}.',
              element: method,
            );
          }

          final tabletMethod = findMethod(tabletName);
          if (tabletName != null && tabletMethod == null) {
            throw InvalidGenerationSourceError(
              'Method "$tabletName" referenced in @Responsive on "${method.name}" was not found in ${element.name}.',
              element: method,
            );
          }

          final desktopMethod = findMethod(desktopName);
          if (desktopName != null && desktopMethod == null) {
            throw InvalidGenerationSourceError(
              'Method "$desktopName" referenced in @Responsive on "${method.name}" was not found in ${element.name}.',
              element: method,
            );
          }

          responsiveInfo = _ResponsiveInfo(
            mobileMethod: mobileMethod,
            tabletMethod: tabletMethod,
            desktopMethod: desktopMethod,
            attachStates: attachStates,
          );
        }

        variantMethods.add(_VariantMethodInfo(
          name: method.name!,
          method: method,
          isDefault: isDefault,
          aliases: aliases,
          responsiveInfo: responsiveInfo,
          docComment: method.documentationComment,
        ));
      }
    }

    if (variantMethods.isEmpty) {
      throw InvalidGenerationSourceError(
        'Class ${element.name} must declare at least one static variant method returning Style.',
        element: element,
      );
    }

    // Default variant fallback
    var defaultVariant = variantMethods.firstWhere(
      (v) => v.isDefault,
      orElse: () => variantMethods.first,
    );

    // Collect fields & constructor parameters
    final fieldsMap = <String, _PresetFieldInfo>{};

    void processMethodParams(MethodElement? method) {
      if (method == null) return;
      for (final param in method.formalParameters) {
        if (_isSpecialParam(param)) continue;

        final isNullable =
            param.type.nullabilitySuffix == NullabilitySuffix.question;
        fieldsMap[param.name!] = _PresetFieldInfo(
          name: param.name!,
          typeName: param.type.getDisplayString(),
          defaultValueCode: param.defaultValueCode,
          isRequired: param.isRequiredNamed,
          isNullable: isNullable,
        );
      }
    }

    processMethodParams(baseMethod);
    for (final vm in variantMethods) {
      processMethodParams(vm.method);
      if (vm.responsiveInfo != null) {
        processMethodParams(vm.responsiveInfo!.mobileMethod);
        processMethodParams(vm.responsiveInfo!.tabletMethod);
        processMethodParams(vm.responsiveInfo!.desktopMethod);
      }
    }

    // Also collect non-static fields declared directly on the spec class
    for (final field in element.fields) {
      if (!field.isStatic && !fieldsMap.containsKey(field.name!)) {
        final isNullable =
            field.type.nullabilitySuffix == NullabilitySuffix.question;
        fieldsMap[field.name!] = _PresetFieldInfo(
          name: field.name!,
          typeName: field.type.getDisplayString(),
          defaultValueCode: null,
          isRequired: false,
          isNullable: isNullable,
        );
      }
    }

    final fields = fieldsMap.values.toList();
    final buffer = StringBuffer();

    // 1. Generate Variants Enum if enabled
    if (generateVariantsEnum) {
      buffer.writeln('/// Variant options for [$className].');
      buffer.writeln('enum $variantEnumName {');
      for (final vm in variantMethods) {
        _writeDocComment(buffer, vm.docComment, indent: '  ');
        buffer.writeln('  ${vm.name},');
      }
      buffer.writeln('}');
      buffer.writeln();
    }

    // 2. Generate StyleResolver Class
    if (element.documentationComment != null) {
      _writeDocComment(buffer, element.documentationComment, indent: '');
      buffer.writeln('///');
      buffer.writeln('/// Reusable style preset generated from [${element.name}].');
    } else {
      buffer.writeln('/// Reusable style preset generated from [${element.name}].');
    }
    buffer.writeln('class $className extends StyleResolver {');
    buffer.writeln('  final $variantEnumName variant;');
    for (final field in fields) {
      buffer.writeln('  final ${field.typeName} ${field.name};');
    }
    buffer.writeln();

    // Build constructor parameter definitions
    final ctorParams = _buildConstructorParams(fields);

    // Default constructor
    if (defaultVariant.docComment != null) {
      _writeDocComment(buffer, defaultVariant.docComment, indent: '  ');
    } else {
      buffer.writeln('  /// Creates a default [$className] preset using [${defaultVariant.name}].');
    }
    if (ctorParams.isEmpty) {
      buffer.writeln('  const $className() : variant = $variantEnumName.${defaultVariant.name};');
    } else {
      buffer.writeln('  const $className({');
      buffer.writeln(ctorParams);
      buffer.writeln('  }) : variant = $variantEnumName.${defaultVariant.name};');
    }

    // Named constructors for each variant
    for (final vm in variantMethods) {
      if (vm.docComment != null) {
        _writeDocComment(buffer, vm.docComment, indent: '  ');
      } else {
        buffer.writeln('  /// Creates a [$className] preset with [$variantEnumName.${vm.name}] variant.');
      }
      if (ctorParams.isEmpty) {
        buffer.writeln('  const $className.${vm.name}() : variant = $variantEnumName.${vm.name};');
      } else {
        buffer.writeln('  const $className.${vm.name}({');
        buffer.writeln(ctorParams);
        buffer.writeln('  }) : variant = $variantEnumName.${vm.name};');
      }

      // Constructor aliases
      for (final alias in vm.aliases) {
        if (vm.docComment != null) {
          _writeDocComment(buffer, vm.docComment, indent: '  ');
        } else {
          buffer.writeln('  /// Alias constructor for [$className.${vm.name}].');
        }
        if (ctorParams.isEmpty) {
          buffer.writeln('  const $className.$alias() : variant = $variantEnumName.${vm.name};');
        } else {
          buffer.writeln('  const $className.$alias({');
          buffer.writeln(ctorParams);
          buffer.writeln('  }) : variant = $variantEnumName.${vm.name};');
        }
      }
    }

    // Dynamic fromVariant constructor
    if (ctorParams.isEmpty) {
      buffer.writeln('  const $className.fromVariant(this.variant);');
    } else {
      buffer.writeln('  const $className.fromVariant(');
      buffer.writeln('    this.variant, {');
      buffer.writeln(ctorParams);
      buffer.writeln('  });');
    }
    buffer.writeln();

    // 3. Generate resolve method
    buffer.writeln('  @override');
    buffer.writeln('  Style resolve(BuildContext context) {');
    final needsTheme = (baseMethod != null && _methodNeedsTheme(baseMethod)) ||
        variantMethods.any((vm) =>
            _methodNeedsTheme(vm.method) ||
            (vm.responsiveInfo?.mobileMethod != null &&
                _methodNeedsTheme(vm.responsiveInfo!.mobileMethod!)) ||
            (vm.responsiveInfo?.tabletMethod != null &&
                _methodNeedsTheme(vm.responsiveInfo!.tabletMethod!)) ||
            (vm.responsiveInfo?.desktopMethod != null &&
                _methodNeedsTheme(vm.responsiveInfo!.desktopMethod!)));

    final needsScreen = (baseMethod != null && _methodNeedsScreen(baseMethod)) ||
        variantMethods.any((vm) =>
            _methodNeedsScreen(vm.method) ||
            vm.responsiveInfo != null ||
            (vm.responsiveInfo?.mobileMethod != null &&
                _methodNeedsScreen(vm.responsiveInfo!.mobileMethod!)) ||
            (vm.responsiveInfo?.tabletMethod != null &&
                _methodNeedsScreen(vm.responsiveInfo!.tabletMethod!)) ||
            (vm.responsiveInfo?.desktopMethod != null &&
                _methodNeedsScreen(vm.responsiveInfo!.desktopMethod!)));

    final needsSize = (baseMethod != null && _methodNeedsSize(baseMethod)) ||
        variantMethods.any((vm) =>
            _methodNeedsSize(vm.method) ||
            (vm.responsiveInfo?.mobileMethod != null &&
                _methodNeedsSize(vm.responsiveInfo!.mobileMethod!)) ||
            (vm.responsiveInfo?.tabletMethod != null &&
                _methodNeedsSize(vm.responsiveInfo!.tabletMethod!)) ||
            (vm.responsiveInfo?.desktopMethod != null &&
                _methodNeedsSize(vm.responsiveInfo!.desktopMethod!)));

    if (needsTheme) {
      buffer.writeln('    final theme = context.theme;');
    }
    if (needsScreen && needsSize) {
      buffer.writeln(
          '    final (screen: screen, size: size) = StyledScreen.fromContext(context);');
    } else if (needsScreen) {
      buffer.writeln(
          '    final (screen: screen, size: _) = StyledScreen.fromContext(context);');
    } else if (needsSize) {
      buffer.writeln(
          '    final (screen: _, size: size) = StyledScreen.fromContext(context);');
    }

    final hasBase = baseMethod != null;
    if (hasBase) {
      final baseCall = _buildMethodCall(element.name!, baseMethod);
      buffer.writeln('    final baseStyle = $baseCall;');
    }

    buffer.writeln('    final variantStyle = switch (variant) {');
    for (final vm in variantMethods) {
      final resp = vm.responsiveInfo;
      if (resp == null) {
        final methodCall = _buildMethodCall(element.name!, vm.method);
        buffer.writeln('      $variantEnumName.${vm.name} => $methodCall,');
      } else {
        final mobileCall = resp.mobileMethod != null
            ? _buildMethodCall(element.name!, resp.mobileMethod!)
            : null;
        final tabletCall = resp.tabletMethod != null
            ? _buildMethodCall(element.name!, resp.tabletMethod!)
            : null;
        final desktopCall = resp.desktopMethod != null
            ? _buildMethodCall(element.name!, resp.desktopMethod!)
            : _buildMethodCall(element.name!, vm.method);

        if (resp.attachStates) {
          buffer.writeln('      $variantEnumName.${vm.name} => () {');
          buffer.writeln('        final desktopStyle = $desktopCall;');
          if (tabletCall != null) {
            buffer.writeln('        final tabletStyle = $tabletCall;');
          } else {
            buffer.writeln('        final tabletStyle = desktopStyle;');
          }
          if (mobileCall != null) {
            buffer.writeln('        final mobileStyle = $mobileCall;');
          } else {
            buffer.writeln('        final mobileStyle = desktopStyle;');
          }
          buffer.writeln('        final base = switch (screen) {');
          buffer.writeln('          StyledScreen.mobile => mobileStyle,');
          buffer.writeln('          StyledScreen.tablet => tabletStyle,');
          buffer.writeln('          StyledScreen.desktop => desktopStyle,');
          buffer.writeln('        };');
          buffer.writeln('        return base');
          buffer.writeln('            .on(StyledScreen.tablet.name, style: tabletStyle)');
          buffer.writeln('            .on(StyledScreen.mobile.name, style: mobileStyle);');
          buffer.writeln('      }(),');
        } else {
          buffer.writeln('      $variantEnumName.${vm.name} => switch (screen) {');
          if (mobileCall != null) {
            buffer.writeln('        StyledScreen.mobile => $mobileCall,');
          }
          if (tabletCall != null) {
            buffer.writeln('        StyledScreen.tablet => $tabletCall,');
          }
          if (mobileCall != null && tabletCall != null) {
            buffer.writeln('        StyledScreen.desktop => $desktopCall,');
          } else {
            buffer.writeln('        _ => $desktopCall,');
          }
          buffer.writeln('      },');
        }
      }
    }
    buffer.writeln('    };');

    if (hasBase && mergeBase) {
      buffer.writeln('    return baseStyle.merge(variantStyle) as Style;');
    } else {
      buffer.writeln('    return variantStyle;');
    }
    buffer.writeln('  }');
    buffer.writeln();

    // 4. Generate copyWith
    buffer.writeln('  /// Creates a copy with the given overrides.');
    buffer.writeln('  $className copyWith({');
    buffer.writeln('    $variantEnumName? variant,');
    for (final field in fields) {
      final nullableType = field.typeName.endsWith('?')
          ? field.typeName
          : '${field.typeName}?';
      buffer.writeln('    $nullableType ${field.name},');
    }
    buffer.writeln('  }) {');
    buffer.writeln('    return $className.fromVariant(');
    buffer.writeln('      variant ?? this.variant,');
    for (final field in fields) {
      buffer.writeln('      ${field.name}: ${field.name} ?? this.${field.name},');
    }
    buffer.writeln('    );');
    buffer.writeln('  }');
    buffer.writeln();

    // 5. Generate operator == and hashCode
    buffer.writeln('  @override');
    buffer.writeln('  bool operator ==(Object other) =>');
    buffer.writeln('      identical(this, other) ||');
    buffer.writeln('      other is $className &&');
    buffer.writeln('          runtimeType == other.runtimeType &&');
    final equalityChecks = ['variant == other.variant', ...fields.map((f) => '${f.name} == other.${f.name}')];
    buffer.writeln('          ${equalityChecks.join(' &&\n          ')};');
    buffer.writeln();

    buffer.writeln('  @override');
    if (fields.isEmpty) {
      buffer.writeln('  int get hashCode => variant.hashCode;');
    } else {
      buffer.writeln('  int get hashCode => Object.hash(variant, ${fields.map((f) => f.name).join(', ')});');
    }

    buffer.writeln('}');
    return buffer.toString();
  }

  static void _writeDocComment(StringBuffer buffer, String? docComment, {String indent = '  '}) {
    if (docComment == null) return;
    for (final line in docComment.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.isNotEmpty) {
        buffer.writeln('$indent$trimmed');
      }
    }
  }

  static String _deriveClassName(String elementName) {
    var name = elementName;
    if (name.startsWith('_')) name = name.substring(1);
    if (name.endsWith('Spec')) name = name.substring(0, name.length - 4);
    if (name.endsWith('Preset')) name = name.substring(0, name.length - 6);
    if (!name.startsWith('Style')) name = 'Style$name';
    return name;
  }

  static String _deriveVariantEnumName(String className) {
    var base = className;
    if (base.startsWith('Style')) base = base.substring(5);
    return '${base}Variant';
  }

  static bool _isSpecialParam(FormalParameterElement param) {
    final typeName = param.type.getDisplayString();
    return typeName.contains('StyledTheme') ||
        typeName.contains('BuildContext') ||
        typeName.contains('StyledScreen') ||
        (typeName == 'Size' && param.name == 'size') ||
        param.name == 'theme' ||
        param.name == 'context' ||
        param.name == 'screen';
  }

  static bool _methodNeedsTheme(MethodElement method) {
    return method.formalParameters.any((p) {
      final typeName = p.type.getDisplayString();
      return typeName.contains('StyledTheme') || p.name == 'theme';
    });
  }

  static bool _methodNeedsScreen(MethodElement method) {
    return method.formalParameters.any((p) {
      final typeName = p.type.getDisplayString();
      return typeName.contains('StyledScreen') || p.name == 'screen';
    });
  }

  static bool _methodNeedsSize(MethodElement method) {
    return method.formalParameters.any((p) {
      final typeName = p.type.getDisplayString();
      return typeName == 'Size' && p.name == 'size';
    });
  }

  static String _buildConstructorParams(List<_PresetFieldInfo> fields) {
    if (fields.isEmpty) return '';
    return fields.map((f) {
      if (f.isRequired) {
        return '    required this.${f.name},';
      }
      if (f.defaultValueCode != null) {
        return '    this.${f.name} = ${f.defaultValueCode},';
      }
      return '    this.${f.name},';
    }).join('\n');
  }

  static String _buildMethodCall(String className, MethodElement method) {
    final args = <String>[];
    for (final param in method.formalParameters) {
      final typeName = param.type.getDisplayString();
      String value;
      if (typeName.contains('BuildContext') || param.name == 'context') {
        value = 'context';
      } else if (typeName.contains('StyledTheme') || param.name == 'theme') {
        value = 'theme';
      } else if (typeName.contains('StyledScreen') || param.name == 'screen') {
        value = 'screen';
      } else if (typeName == 'Size' && param.name == 'size') {
        value = 'size';
      } else {
        value = param.name!;
      }

      if (param.isNamed) {
        args.add('${param.name}: $value');
      } else {
        args.add(value);
      }
    }
    return '$className.${method.name}(${args.join(', ')})';
  }
}

class _ResponsiveInfo {
  final MethodElement? mobileMethod;
  final MethodElement? tabletMethod;
  final MethodElement? desktopMethod;
  final bool attachStates;

  _ResponsiveInfo({
    this.mobileMethod,
    this.tabletMethod,
    this.desktopMethod,
    this.attachStates = false,
  });
}

class _VariantMethodInfo {
  final String name;
  final MethodElement method;
  final bool isDefault;
  final List<String> aliases;
  final _ResponsiveInfo? responsiveInfo;
  final String? docComment;

  _VariantMethodInfo({
    required this.name,
    required this.method,
    required this.isDefault,
    required this.aliases,
    this.responsiveInfo,
    this.docComment,
  });
}

class _PresetFieldInfo {
  final String name;
  final String typeName;
  final String? defaultValueCode;
  final bool isRequired;
  final bool isNullable;

  _PresetFieldInfo({
    required this.name,
    required this.typeName,
    this.defaultValueCode,
    required this.isRequired,
    required this.isNullable,
  });
}
