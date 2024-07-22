import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

abstract class InputOTPChild {
  static InputOTPChild get separator =>
      const WidgetInputOTPChild(OTPSeparator());
  static InputOTPChild get space =>
      const WidgetInputOTPChild(SizedBox(width: 8));
  static InputOTPChild get empty =>
      const WidgetInputOTPChild(SizedBox(width: 0));
  factory InputOTPChild.input({
    CodepointPredicate? predicate,
    CodepointUnaryOperator? transform,
    bool obscured = false,
  }) =>
      CharacterInputOTPChild(
        predicate: predicate,
        transform: transform,
        obscured: obscured,
      );
  factory InputOTPChild.character({
    bool allowLowercaseAlphabet = false,
    bool allowUppercaseAlphabet = false,
    bool allowDigit = false,
    bool obscured = false,
    bool onlyUppercaseAlphabet = false,
    bool onlyLowercaseAlphabet = false,
  }) {
    assert(!(onlyUppercaseAlphabet && onlyLowercaseAlphabet),
        'onlyUppercaseAlphabet and onlyLowercaseAlphabet cannot be true at the same time');
    return CharacterInputOTPChild(
      predicate: (codepoint) {
        if (allowLowercaseAlphabet &&
            CharacterInputOTPChild.isAlphabetLower(codepoint)) {
          return true;
        }
        if (allowUppercaseAlphabet &&
            CharacterInputOTPChild.isAlphabetUpper(codepoint)) {
          return true;
        }
        if (allowDigit && CharacterInputOTPChild.isDigit(codepoint)) {
          return true;
        }
        return false;
      },
      transform: (codepoint) {
        if (onlyUppercaseAlphabet) {
          return CharacterInputOTPChild.lowerToUpper(codepoint);
        }
        if (onlyLowercaseAlphabet) {
          return CharacterInputOTPChild.upperToLower(codepoint);
        }
        return codepoint;
      },
      obscured: obscured,
    );
  }
  const InputOTPChild();
  Widget build(BuildContext context, InputOTPChildData data);
  bool get hasValue;
}

typedef CodepointPredicate = bool Function(int codepoint);
typedef CodepointUnaryOperator = int Function(int codepoint);

class CharacterInputOTPChild extends InputOTPChild {
  static const int _startAlphabetLower = 97; // 'a'
  static const int _endAlphabetLower = 122; // 'z'
  static const int _startAlphabetUpper = 65; // 'A'
  static const int _endAlphabetUpper = 90; // 'Z'
  static const int _startDigit = 48; // '0'
  static const int _endDigit = 57; // '9'

  static bool isAlphabetLower(int codepoint) =>
      codepoint >= _startAlphabetLower && codepoint <= _endAlphabetLower;
  static bool isAlphabetUpper(int codepoint) =>
      codepoint >= _startAlphabetUpper && codepoint <= _endAlphabetUpper;
  static int lowerToUpper(int codepoint) =>
      isAlphabetLower(codepoint) ? codepoint - 32 : codepoint;
  static int upperToLower(int codepoint) =>
      isAlphabetUpper(codepoint) ? codepoint + 32 : codepoint;
  static bool isDigit(int codepoint) =>
      codepoint >= _startDigit && codepoint <= _endDigit;

  final CodepointPredicate? predicate;
  final CodepointUnaryOperator? transform;
  final bool obscured;

  const CharacterInputOTPChild({
    this.predicate,
    this.transform,
    this.obscured = false,
  });

  @override
  bool get hasValue {
    return true;
  }

  @override
  Widget build(BuildContext context, InputOTPChildData data) {
    return _OTPCharacterInput(
      key: data._key,
      data: data,
      predicate: predicate,
      transform: transform,
      obscured: obscured,
    );
  }
}

class _OTPCharacterInput extends StatefulWidget {
  final InputOTPChildData data;
  final CodepointPredicate? predicate;
  final CodepointUnaryOperator? transform;
  final bool obscured;

  const _OTPCharacterInput({
    super.key,
    required this.data,
    this.predicate,
    this.transform,
    this.obscured = false,
  });

  @override
  State<_OTPCharacterInput> createState() => _OTPCharacterInputState();
}

class _OTPCharacterInputState extends State<_OTPCharacterInput> {
  final TextEditingController _controller = TextEditingController();
  late int? _value;

  @override
  void initState() {
    super.initState();
    _value = widget.data.value;
    _controller.addListener(_onControllerChanged);
  }

  void _onControllerChanged() {
    String text = _controller.text;
    if (text.isNotEmpty) {
      int codepoint = text.codeUnitAt(0);
      if (text.length > 1) {
        // forward to the next input
        var currentIndex = widget.data.index;
        var inputs = widget.data._state._children;
        if (currentIndex + 1 < inputs.length) {
          var nextInput = inputs[currentIndex + 1];
          nextInput.key.currentState?._controller.text = text.substring(1);
          if (text.length == 2) {
            WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
              nextInput.key.currentState?._controller.text = text.substring(1);
            });
          } else {
            nextInput.key.currentState?._controller.text = text.substring(1);
          }
        }
      }
      if (widget.predicate != null && !widget.predicate!(codepoint)) {
        _value = null;
        _controller.clear();
        setState(() {});
        return;
      }
      if (widget.transform != null) {
        codepoint = widget.transform!(codepoint);
      }
      _value = codepoint;
      widget.data.changeValue(codepoint);
      _controller.clear();
      // next focus
      if (widget.data.nextFocusNode != null) {
        widget.data.nextFocusNode!.requestFocus();
      }
      setState(() {});
    }
  }

  BorderRadius getBorderRadiusByRelativeIndex(
      ThemeData theme, int relativeIndex, int groupLength) {
    if (relativeIndex == 0) {
      return BorderRadius.only(
        topLeft: Radius.circular(theme.radiusMd),
        bottomLeft: Radius.circular(theme.radiusMd),
      );
    } else if (relativeIndex == groupLength - 1) {
      return BorderRadius.only(
        topRight: Radius.circular(theme.radiusMd),
        bottomRight: Radius.circular(theme.radiusMd),
      );
    } else {
      return BorderRadius.zero;
    }
  }

  Widget getValueWidget(ThemeData theme) {
    if (_value == null) {
      return const SizedBox();
    }
    if (widget.obscured) {
      return Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          color: theme.colorScheme.foreground,
          shape: BoxShape.circle,
        ),
      );
    }
    return Text(
      String.fromCharCode(_value!),
    ).small().foreground();
  }

  final FocusScopeNode _focusScopeNode = FocusScopeNode();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return FocusScope(
      node: _focusScopeNode,
      onKeyEvent: (node, event) {
        if (event is KeyUpEvent) {
          if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
            if (widget.data.previousFocusNode != null) {
              widget.data.previousFocusNode!.requestFocus();
            }
            return KeyEventResult.handled;
          }
          if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
            if (widget.data.nextFocusNode != null) {
              widget.data.nextFocusNode!.requestFocus();
            }
            return KeyEventResult.handled;
          }
          // backspace
          if (event.logicalKey == LogicalKeyboardKey.backspace) {
            if (_value != null) {
              // widget.data.focusNode!.requestFocus();
              // SEE ISSUE: https://github.com/flutter/flutter/issues/95553
              widget.data.changeValue(null);
              _value = null;
              setState(() {});
              widget.data.focusNode!.unfocus();
              Future.delayed(const Duration(milliseconds: 5), () {
                widget.data.focusNode!.requestFocus();
              });
            } else {
              if (widget.data.previousFocusNode != null) {
                widget.data.previousFocusNode!.requestFocus();
              }
            }
            return KeyEventResult.handled;
          }
          // enter
          if (event.logicalKey == LogicalKeyboardKey.enter) {
            if (_controller.text.isNotEmpty) {
              _onControllerChanged();
            }
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: SizedBox(
        width: 36,
        height: 36,
        child: Stack(
          children: [
            Positioned.fill(
              child: AnimatedBuilder(
                animation: widget.data.focusNode!,
                builder: (context, child) {
                  if (widget.data.focusNode!.hasFocus) {
                    return Container(
                      decoration: BoxDecoration(
                        border: Border.all(
                            color: theme.colorScheme.ring,
                            strokeAlign: BorderSide.strokeAlignOutside),
                        borderRadius: getBorderRadiusByRelativeIndex(
                          theme,
                          widget.data.relativeIndex,
                          widget.data.groupLength,
                        ),
                      ),
                    );
                  } else {
                    return Container(
                      decoration: BoxDecoration(
                        border: Border.all(
                            color: theme.colorScheme.border,
                            strokeAlign: BorderSide.strokeAlignOutside),
                        borderRadius: getBorderRadiusByRelativeIndex(
                          theme,
                          widget.data.relativeIndex,
                          widget.data.groupLength,
                        ),
                      ),
                    );
                  }
                },
              ),
            ),
            if (_value != null)
              Positioned.fill(
                child: IgnorePointer(
                  child: Center(
                    child: getValueWidget(theme),
                  ),
                ),
              ),
            Positioned.fill(
              child: Opacity(
                opacity: _value == null ? 1 : 0,
                child: TextField(
                  border: false,
                  textAlign: TextAlign.center,
                  focusNode: widget.data.focusNode,
                  controller: _controller,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class WidgetInputOTPChild extends InputOTPChild {
  final Widget child;

  const WidgetInputOTPChild(this.child);

  @override
  Widget build(BuildContext context, InputOTPChildData data) {
    return SizedBox(
      width: 36,
      height: 36,
      child: Center(
        child: child,
      ),
    );
  }

  @override
  bool get hasValue => false;
}

class OTPSeparator extends StatelessWidget {
  const OTPSeparator({super.key});

  @override
  Widget build(BuildContext context) {
    return const Text('-').bold().withPadding(horizontal: 4).foreground();
  }
}

class InputOTPChildData {
  final FocusNode? previousFocusNode;
  final FocusNode? focusNode;
  final FocusNode? nextFocusNode;
  final int index;
  final int groupIndex;
  final int groupLength;
  final int relativeIndex;
  final int? value;
  final _InputOTPState _state;
  final GlobalKey<_OTPCharacterInputState>? _key;

  InputOTPChildData._(
    this._state,
    this._key, {
    required this.focusNode,
    required this.index,
    required this.groupIndex,
    required this.relativeIndex,
    required this.groupLength,
    this.previousFocusNode,
    this.nextFocusNode,
    this.value,
  });

  void changeValue(int? value) {
    _state._changeValue(index, value);
  }
}

class _InputOTPChild {
  int? value;
  final FocusNode focusNode;
  final InputOTPChild child;
  final int groupIndex;
  final int relativeIndex;
  int groupLength = 0;
  final GlobalKey<_OTPCharacterInputState> key = GlobalKey();

  _InputOTPChild({
    required this.focusNode,
    required this.child,
    this.value,
    required this.groupIndex,
    required this.relativeIndex,
  });
}

typedef OTPCodepointList = List<int?>;

extension OTPCodepointListExtension on OTPCodepointList {
  String otpToString() {
    return map((e) => e == null ? '' : String.fromCharCode(e)).join();
  }
}

class InputOTP extends StatefulWidget {
  final List<InputOTPChild> children;
  final OTPCodepointList? initialValue;
  final ValueChanged<OTPCodepointList>? onChanged;
  final ValueChanged<OTPCodepointList>? onSubmitted;

  const InputOTP({
    super.key,
    required this.children,
    this.initialValue,
    this.onChanged,
    this.onSubmitted,
  });

  @override
  State<InputOTP> createState() => _InputOTPState();
}

class _InputOTPState extends State<InputOTP> {
  final List<_InputOTPChild> _children = [];

  OTPCodepointList get value {
    return _children.map((e) => e.value).toList();
  }

  void _changeValue(int index, int? value) {
    if (widget.onChanged != null) {
      _children[index].value = value;
      var val = this.value;
      widget.onChanged!(val);
      if (val.every((e) => e != null)) {
        widget.onSubmitted?.call(val);
      }
    }
  }

  @override
  void initState() {
    super.initState();
    int index = 0;
    int groupIndex = 0;
    int relativeIndex = 0;
    for (final child in widget.children) {
      if (child.hasValue) {
        int? value = getInitialValue(index);
        _children.add(_InputOTPChild(
          focusNode: FocusNode(),
          child: child,
          value: value,
          groupIndex: groupIndex,
          relativeIndex: relativeIndex,
        ));
        index++;
        relativeIndex++;
      } else {
        // update previous group length
        for (int i = 0; i < index; i++) {
          _children[i].groupLength = relativeIndex;
        }
        groupIndex++;
        relativeIndex = 0;
      }
    }
    for (int i = index - relativeIndex; i < index; i++) {
      _children[i].groupLength = relativeIndex;
    }
  }

  int? getInitialValue(int index) {
    if (widget.initialValue != null && index < widget.initialValue!.length) {
      return widget.initialValue![index];
    }
    return null;
  }

  @override
  void didUpdateWidget(covariant InputOTP oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!listEquals(oldWidget.initialValue, widget.initialValue) ||
        !listEquals(oldWidget.children, widget.children)) {
      int index = 0;
      int groupIndex = 0;
      int relativeIndex = 0;
      for (final child in widget.children) {
        if (child.hasValue) {
          int? value = getInitialValue(index);
          _children.add(_InputOTPChild(
            focusNode: FocusNode(),
            child: child,
            value: value,
            groupIndex: groupIndex,
            relativeIndex: relativeIndex,
          ));
          index++;
          relativeIndex++;
        } else {
          // update previous group length
          for (int i = index - relativeIndex; i < index; i++) {
            _children[i].groupLength = relativeIndex;
          }
          groupIndex++;
          relativeIndex = 0;
        }
      }
      for (int i = index - relativeIndex; i < index; i++) {
        _children[i].groupLength = relativeIndex;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    List<Widget> children = [];
    int i = 0;
    for (final child in widget.children) {
      if (child.hasValue) {
        children.add(child.build(
          context,
          InputOTPChildData._(
            this,
            _children[i].key,
            focusNode: _children[i].focusNode,
            index: i,
            groupIndex: _children[i].groupIndex,
            relativeIndex: _children[i].relativeIndex,
            previousFocusNode: i == 0 ? null : _children[i - 1].focusNode,
            nextFocusNode:
                i == _children.length - 1 ? null : _children[i + 1].focusNode,
            value: _children[i].value,
            groupLength: _children[i].groupLength,
          ),
        ));
        i++;
      } else {
        children.add(child.build(
            context,
            InputOTPChildData._(
              this,
              null,
              focusNode: null,
              index: -1,
              groupIndex: -1,
              relativeIndex: -1,
              previousFocusNode: null,
              nextFocusNode: null,
              value: null,
              groupLength: -1,
            )));
      }
    }
    return SizedBox(
      height: 36,
      child: IntrinsicWidth(
        child: Row(
          children: [
            for (final child in children) Expanded(child: child),
          ],
        ),
      ),
    );
  }
}