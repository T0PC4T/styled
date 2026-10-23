import 'dart:ui' as ui show BoxHeightStyle, BoxWidthStyle;
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../core/style.dart';
import '../theme/styled_theme.dart';
import 'styled_box.dart';
import 'styled_text.dart';

/// The chassis of a styled field: optional label, the decorated box with
/// leading and trailing icons, and an optional error message.
///
/// The box activates [StyleState.focused], [StyleState.error] and
/// [StyleState.disabled] in that order of precedence. The gap between icons
/// and the field is `style.flex.spacing`. The label and error inherit text
/// from the surrounding style unless [labelStyle] or [errorStyle] is given;
/// the error message defaults to the text of the style's error state.
class StyledInput extends StatelessWidget {
  final StyleResolver style;
  final String? label;
  final StyleResolver? labelStyle;
  final Widget? icon;
  final Widget? suffixIcon;
  final String? error;
  final StyleResolver? errorStyle;
  final bool isFocused;
  final bool enabled;
  final Widget child;
  final String? hint;
  final bool showHint;
  final String? semanticLabel;
  final int? maxLines;
  final TextOverflow? overflow;

  /// Vertical gap between the label, the box and the error message.
  final double labelSpacing;

  const StyledInput({
    super.key,
    required this.style,
    required this.child,
    this.label,
    this.labelStyle,
    this.icon,
    this.suffixIcon,
    this.error,
    this.errorStyle,
    this.isFocused = false,
    this.enabled = true,
    this.hint,
    this.showHint = false,
    this.semanticLabel,
    this.maxLines,
    this.overflow,
    this.labelSpacing = 4.0,
  });

  bool get _hasError => error != null && error!.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final resolved = style.resolve(context);
    final current = resolved.resolveStates([
      if (isFocused && enabled) StyleState.focused,
      if (_hasError) StyleState.error,
      if (!enabled) StyleState.disabled,
    ], context: context);

    Widget content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      spacing: labelSpacing,
      children: [
        if (label case final label? when label.isNotEmpty) StyledText(label, style: labelStyle),
        StyledBox(
          style: current,
          child: Row(
            spacing: StyledTheme.of(context).read(current.flex.spacing) ?? 0.0,
            children: [
              ?icon,
              Expanded(
                child: Stack(
                  alignment: Alignment.centerLeft,
                  children: [
                    if (showHint && hint != null && hint!.isNotEmpty)
                      IgnorePointer(
                        child: Opacity(
                          opacity: 0.5,
                          child: StyledText(
                            hint!,
                            style: Style(
                              text: StyledTextStyle(
                                maxLines: maxLines ?? 1,
                                overflow: overflow ?? TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ),
                      ),
                    child,
                  ],
                ),
              ),
              ?suffixIcon,
            ],
          ),
        ),
        if (_hasError)
          StyledText(
            error!,
            style: errorStyle ?? Style(text: resolved.states[StyleState.error]?.text ?? const StyledTextStyle()),
          ),
      ],
    );

    if (semanticLabel != null) {
      content = Semantics(label: semanticLabel, textField: true, enabled: enabled, child: content);
    }
    return content;
  }
}

/// A Material-independent, headless styled text field powered by [EditableText].
///
/// Features native text selection highlighting, drag-selection, word/paragraph selection,
/// deletion (character, word, line, and selection block), keyboard shortcuts, context menus,
/// and token-driven visual decoration wrapped in [StyledBox] and [StyledInput].
class StyledTextField extends StatefulWidget {
  final StyleResolver style;
  final String? label;
  final StyleResolver? labelStyle;
  final String hint;
  final Widget? icon;
  final Widget? suffixIcon;
  final int minLines;
  final int? maxLines;
  final int? maxLength;
  final FocusNode? focusNode;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onEditingComplete;
  final VoidCallback? onTap;
  final TapRegionCallback? onTapOutside;
  final List<TextInputFormatter>? inputFormatters;
  final TextCapitalization textCapitalization;
  final TextInputAction? textInputAction;
  final bool autofocus;
  final bool obscureText;
  final String obscuringCharacter;
  final TextInputType? keyboardType;
  final bool enableInteractiveSelection;
  final bool readOnly;
  final bool enabled;
  final bool? showCursor;
  final Color? cursorColor;
  final Color? selectionColor;
  final TextSelectionControls? selectionControls;
  final EditableTextContextMenuBuilder? contextMenuBuilder;
  final TextEditingController? controller;
  final String? error;
  final StyleResolver? errorStyle;
  final String? semanticLabel;
  final double cursorWidth;
  final Radius? cursorRadius;

  /// Vertical gap between the label, the box and the error message.
  final double labelSpacing;

  const StyledTextField({
    super.key,
    required this.style,
    this.label,
    this.labelStyle,
    this.icon,
    this.suffixIcon,
    this.error,
    this.errorStyle,
    this.hint = '',
    this.minLines = 1,
    this.maxLines = 1,
    this.maxLength,
    this.focusNode,
    this.onChanged,
    this.onSubmitted,
    this.onEditingComplete,
    this.onTap,
    this.onTapOutside,
    this.inputFormatters,
    this.autofocus = false,
    this.obscureText = false,
    this.obscuringCharacter = '•',
    this.textCapitalization = TextCapitalization.none,
    this.textInputAction,
    this.keyboardType,
    this.enableInteractiveSelection = true,
    this.readOnly = false,
    this.enabled = true,
    this.showCursor,
    this.cursorColor,
    this.selectionColor,
    this.selectionControls,
    this.contextMenuBuilder,
    this.controller,
    this.semanticLabel,
    this.cursorWidth = 2.0,
    this.cursorRadius = const Radius.circular(1.0),
    this.labelSpacing = 4.0,
  });

  @override
  State<StyledTextField> createState() => _StyledTextFieldState();
}

/// Gesture detector builder delegate for the headless [StyledTextField].
///
/// Because [EditableText] operates with `rendererIgnoresPointer: true`, this builder
/// intercepts tap, drag, double-tap, and long-press gestures, mapping them directly
/// to [RenderEditable] for cursor placement and text selection geometry.
class _StyledTextFieldSelectionGestureDetectorBuilder
    extends TextSelectionGestureDetectorBuilder {
  _StyledTextFieldSelectionGestureDetectorBuilder({
    required _StyledTextFieldState state,
  })  : _state = state,
        super(delegate: state);

  final _StyledTextFieldState _state;

  @override
  void onSingleTapUp(TapDragUpDetails details) {
    super.onSingleTapUp(details);
    // Request system on-screen keyboard on tap and fire caller's onTap callback.
    _state._requestKeyboard();
    _state.widget.onTap?.call();
  }

  @override
  void onSingleLongTapStart(LongPressStartDetails details) {
    super.onSingleLongTapStart(details);
    // Position cursor/selection anchor at long-press coordinate.
    if (delegate.selectionEnabled) {
      renderEditable.selectPositionAt(
        from: details.globalPosition,
        cause: SelectionChangedCause.longPress,
      );
    }
  }

  @override
  void onSingleLongTapMoveUpdate(LongPressMoveUpdateDetails details) {
    // Continuously update selection range during long-press drag.
    if (delegate.selectionEnabled) {
      renderEditable.selectPositionAt(
        from: details.globalPosition,
        cause: SelectionChangedCause.longPress,
      );
    }
  }
}

class _StyledTextFieldState extends State<StyledTextField>
    implements TextSelectionGestureDetectorBuilderDelegate {
  final GlobalKey<EditableTextState> _editableTextKey =
      GlobalKey<EditableTextState>();

  late TextEditingController _controller;
  late FocusNode _focusNode;
  bool _internalController = false;
  bool _internalFocusNode = false;

  late _StyledTextFieldSelectionGestureDetectorBuilder
      _selectionGestureDetectorBuilder;

  @override
  GlobalKey<EditableTextState> get editableTextKey => _editableTextKey;

  @override
  bool get forcePressEnabled => true;

  @override
  bool get selectionEnabled => widget.enableInteractiveSelection;

  EditableTextState? get _editableText => _editableTextKey.currentState;

  @override
  void initState() {
    super.initState();
    _selectionGestureDetectorBuilder =
        _StyledTextFieldSelectionGestureDetectorBuilder(state: this);

    // Provide autonomous fallback controller and focus node when not supplied.
    if (widget.controller == null) {
      _controller = TextEditingController();
      _internalController = true;
    } else {
      _controller = widget.controller!;
    }

    if (widget.focusNode == null) {
      _focusNode = FocusNode();
      _internalFocusNode = true;
    } else {
      _focusNode = widget.focusNode!;
    }

    _controller.addListener(_update);
    _focusNode.addListener(_update);
  }

  @override
  void didUpdateWidget(StyledTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Safely swap and dispose internally managed controllers to prevent memory leaks.
    if (widget.controller != oldWidget.controller) {
      _controller.removeListener(_update);
      if (_internalController) {
        _controller.dispose();
        _internalController = false;
      }
      if (widget.controller == null) {
        _controller = TextEditingController();
        _internalController = true;
      } else {
        _controller = widget.controller!;
      }
      _controller.addListener(_update);
    }
    if (widget.focusNode != oldWidget.focusNode) {
      _focusNode.removeListener(_update);
      if (_internalFocusNode) {
        _focusNode.dispose();
        _internalFocusNode = false;
      }
      if (widget.focusNode == null) {
        _focusNode = FocusNode();
        _internalFocusNode = true;
      } else {
        _focusNode = widget.focusNode!;
      }
      _focusNode.addListener(_update);
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_update);
    if (_internalController) {
      _controller.dispose();
    }
    _focusNode.removeListener(_update);
    if (_internalFocusNode) {
      _focusNode.dispose();
    }
    super.dispose();
  }

  void _update() {
    if (mounted) setState(() {});
  }

  void _requestKeyboard() {
    _editableText?.requestKeyboard();
  }

  void _handleTapOutside(PointerDownEvent event) {
    if (widget.onTapOutside != null) {
      widget.onTapOutside!(event);
    } else {
      _focusNode.unfocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    final resolvedStyle = widget.style.resolve(context);

    return StyledInput(
      style: resolvedStyle,
      label: widget.label,
      labelStyle: widget.labelStyle,
      error: widget.error,
      errorStyle: widget.errorStyle,
      icon: widget.icon,
      suffixIcon: widget.suffixIcon,
      isFocused: _focusNode.hasFocus,
      enabled: widget.enabled,
      hint: widget.hint,
      showHint: _controller.text.isEmpty,
      semanticLabel: widget.semanticLabel,
      maxLines: widget.maxLines,
      labelSpacing: widget.labelSpacing,
      child: Builder(
        builder: (context) {
          final style = InheritedStyle.of(context)?.style ?? resolvedStyle;
          final theme = StyledTheme.of(context);
          final effectiveTextStyle = style.text.toTextStyle(theme);

          // Resolve effective cursor & text selection highlight colors from style cascade.
          final selectionStyle = DefaultSelectionStyle.of(context);
          final effectiveCursorColor = widget.cursorColor ??
              selectionStyle.cursorColor ??
              theme.read(style.text.color) ??
              const Color(0xFF000000);
          final effectiveSelectionColor = widget.selectionColor ??
              theme.read(style.text.selectionColor) ??
              selectionStyle.selectionColor ??
              effectiveCursorColor.withValues(alpha: 0.28);

          final effectiveSelectionControls = widget.selectionControls;

          // 1. Actions / Shortcuts Logic:
          // Wrap EditableText with WidgetsApp.defaultActions to bind desktop keyboard intents
          // (Shift+Arrows for character/line selection, Backspace block deletion, word jumps,
          // Select All via Cmd/Ctrl+A, and clipboard Cut/Copy/Paste operations).
          Widget editable = Actions(
            actions: {
              ...WidgetsApp.defaultActions,
            },
            child: EditableText(
              key: _editableTextKey,
              controller: _controller,
              focusNode: _focusNode,
              style: effectiveTextStyle,
              cursorColor: effectiveCursorColor,
              backgroundCursorColor: const Color(0xFF808080),
              selectionColor: effectiveSelectionColor,
              selectionControls: effectiveSelectionControls,
              keyboardType: widget.keyboardType ??
                  (widget.maxLines == 1
                      ? TextInputType.text
                      : TextInputType.multiline),
              textInputAction: widget.textInputAction,
              textCapitalization: widget.textCapitalization,
              autofocus: widget.autofocus,
              obscureText: widget.obscureText,
              obscuringCharacter: widget.obscuringCharacter,
              minLines: widget.minLines,
              maxLines: widget.maxLines,
              onChanged: widget.onChanged,
              onSubmitted: widget.onSubmitted,
              onEditingComplete: widget.onEditingComplete,
              inputFormatters: [
                if (widget.maxLength != null)
                  LengthLimitingTextInputFormatter(widget.maxLength),
                ...?widget.inputFormatters,
              ],
              rendererIgnoresPointer: true,
              readOnly: widget.readOnly || !widget.enabled,
              showCursor: widget.showCursor ?? widget.enabled,
              showSelectionHandles: true,
              enableInteractiveSelection: widget.enableInteractiveSelection,
              selectionHeightStyle: ui.BoxHeightStyle.tight,
              selectionWidthStyle: ui.BoxWidthStyle.tight,
              cursorWidth: widget.cursorWidth,
              cursorRadius: widget.cursorRadius,
              paintCursorAboveText: true,
              scrollPadding: const EdgeInsets.all(20.0),
              mouseCursor: widget.enabled
                  ? (widget.readOnly
                      ? SystemMouseCursors.basic
                      : SystemMouseCursors.text)
                  : SystemMouseCursors.forbidden,
              contextMenuBuilder: widget.contextMenuBuilder,
            ),
          );

          // 2. Gesture Detector Logic:
          // Wrap with the selection gesture detector to handle taps, drags, double-tap word
          // selection, and triple-tap line selection without conflicts with rendererIgnoresPointer.
          editable = _selectionGestureDetectorBuilder.buildGestureDetector(
            behavior: HitTestBehavior.translucent,
            child: editable,
          );

          // 3. Focus Boundary / Tap Outside Logic:
          // Automatically unfocus and dismiss keyboards when the user taps outside the field.
          if (widget.onTapOutside != null || _focusNode.hasFocus) {
            editable = TapRegion(
              groupId: _editableTextKey,
              onTapOutside: _handleTapOutside,
              child: editable,
            );
          }

          return editable;
        },
      ),
    );
  }
}
