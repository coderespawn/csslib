// Copyright (c) 2012, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

part of parser;

/////////////////////////////////////////////////////////////////////////
// CSS specific types:
/////////////////////////////////////////////////////////////////////////

class Identifier extends Node {
  String name;

  Identifier(this.name, SourceSpan span): super(span);

  visit(TreeVisitor visitor) => visitor.visitIdentifier(this);

  String toString() => name;
}

class Wildcard extends Node {
  Wildcard(SourceSpan span): super(span);

  visit(TreeVisitor visitor) => visitor.visitWildcard(this);

  String toString() => '*';
}

// /*  ....   */
class CssComment extends Node {
  String comment;

  CssComment(this.comment, SourceSpan span): super(span);

  visit(TreeVisitor visitor) => visitor.visitCssComment(this);

  String toString() => '/* ${comment} */';
}

// CDO/CDC (Comment Definition Open <!-- and Comment Definition Close -->).
class CommentDefinition extends CssComment {
  CommentDefinition(String comment, SourceSpan span): super(comment, span);

  visit(TreeVisitor visitor) => visitor.visitCommentDefinition(this);

  String toString() => '<!-- ${comment} -->';
}

class SelectorGroup extends Node {
  List<Selector> _selectors;

  SelectorGroup(this._selectors, SourceSpan span): super(span);

  List<Selector> get selectors => _selectors;

  visit(TreeVisitor visitor) => visitor.visitSelectorGroup(this);

  String toString() {
    StringBuffer buff = new StringBuffer();
    int idx = 0;
    for (final selector in _selectors) {
      if (idx++ > 0) {
        buff.add(', ');
      }
      buff.add(selector.toString());
    }
    return buff.toString();
  }

  /** A multiline string showing the node and its children. */
  String toDebugString() {
    var to = new TreeOutput();
    var tp = new TreePrinter(to);
    this.visit(tp);
    return to.buf.toString();
  }
}

class Selector extends Node {
  List<SimpleSelectorSequence> _simpleSelectorSequences;

  Selector(this._simpleSelectorSequences, SourceSpan span) : super(span);

  List<SimpleSelectorSequence> get simpleSelectorSequences =>
      _simpleSelectorSequences;

  add(SimpleSelectorSequence seq) => _simpleSelectorSequences.add(seq);

  List<SimpleSelectorSequence> get simpleSelectorSquences =>
      _simpleSelectorSequences;

  int get length => _simpleSelectorSequences.length;

  String toString() {
    StringBuffer buff = new StringBuffer();
    for (final simpleSelectorSequence in _simpleSelectorSequences) {
      buff.add(simpleSelectorSequence.toString());
    }
    return buff.toString();
  }

  visit(TreeVisitor visitor) => visitor.visitSelector(this);
}

class SimpleSelectorSequence extends Node {
  int _combinator;              // +, >, ~, NONE
  SimpleSelector _selector;

  SimpleSelectorSequence(this._selector, SourceSpan span,
      [int combinator = TokenKind.COMBINATOR_NONE])
      : _combinator = combinator, super(span);

  get simpleSelector => _selector;

  bool isCombinatorNone() => _combinator == TokenKind.COMBINATOR_NONE;
  bool isCombinatorPlus() => _combinator == TokenKind.COMBINATOR_PLUS;
  bool isCombinatorGreater() => _combinator == TokenKind.COMBINATOR_GREATER;
  bool isCombinatorTilde() => _combinator == TokenKind.COMBINATOR_TILDE;
  bool isCombinatorDescendant() =>
      _combinator == TokenKind.COMBINATOR_DESCENDANT;

  String _combinatorToString() =>
      isCombinatorDescendant() ? ' ' :
      isCombinatorPlus() ? '+' :
      isCombinatorGreater() ? '>' :
      isCombinatorTilde() ? '~' : '';

  visit(TreeVisitor visitor) => visitor.visitSimpleSelectorSequence(this);

  String toString() => '${_combinatorToString()}${_selector}';
}

/* All other selectors (element, #id, .class, attribute, pseudo, negation,
 * namespace, *) are derived from this selector.
 */
class SimpleSelector extends Node {
  var _name;

  SimpleSelector(this._name, SourceSpan span) : super(span);

  // Name can be an Identifier or WildCard we'll return either the name or '*'.
  String get name => isWildcard() ? '*' : _name.name;

  bool isWildcard() => _name is Wildcard;

  visit(TreeVisitor visitor) => visitor.visitSimpleSelector(this);

  String toString() => name;
}

// element name
class ElementSelector extends SimpleSelector {
  ElementSelector(var name, SourceSpan span) : super(name, span);

  visit(TreeVisitor visitor) => visitor.visitElementSelector(this);

  String toString() => "$name";

  /** A multiline string showing the node and its children. */
  String toDebugString() {
    var to = new TreeOutput();
    var tp = new TreePrinter(to);
    this.visit(tp);
    return to.buf.toString();
  }
}

// namespace|element
class NamespaceSelector extends SimpleSelector {
  var _namespace;           // null, Wildcard or Identifier

  NamespaceSelector(this._namespace, var name, SourceSpan span) :
      super(name, span);

  String get namespace => _namespace is Wildcard ? '*' : _namespace.name;

  bool isNamespaceWildcard() => _namespace is Wildcard;

  SimpleSelector get nameAsSimpleSelector => _name;

  visit(TreeVisitor visitor) => visitor.visitNamespaceSelector(this);

  String toString() => "$namespace|${nameAsSimpleSelector.name}";
}

// [attr op value]
class AttributeSelector extends SimpleSelector {
  int _op;
  var _value;

  AttributeSelector(Identifier name, this._op, this._value,
      SourceSpan span) : super(name, span);

  String matchOperator() {
    switch (_op) {
    case TokenKind.EQUALS:
      return '=';
    case TokenKind.INCLUDES:
      return '~=';
    case TokenKind.DASH_MATCH:
      return '|=';
    case TokenKind.PREFIX_MATCH:
      return '^=';
    case TokenKind.SUFFIX_MATCH:
      return '\$=';
    case TokenKind.SUBSTRING_MATCH:
      return '*=';
    }
  }

  // Return the TokenKind for operator used by visitAttributeSelector.
  String matchOperatorAsTokenString() {
    switch (_op) {
    case TokenKind.EQUALS:
      return 'EQUALS';
    case TokenKind.INCLUDES:
      return 'INCLUDES';
    case TokenKind.DASH_MATCH:
      return 'DASH_MATCH';
    case TokenKind.PREFIX_MATCH:
      return 'PREFIX_MATCH';
    case TokenKind.SUFFIX_MATCH:
      return 'SUFFIX_MATCH';
    case TokenKind.SUBSTRING_MATCH:
      return 'SUBSTRING_MATCH';
    }
  }

  String valueToString() {
    if (_value is Identifier) {
      return _value.name;
    } else {
      return '"${_value}"';
    }
  }

  visit(TreeVisitor visitor) => visitor.visitAttributeSelector(this);

  String toString() => "[${name} ${matchOperator()} ${valueToString()}]";
}

// #id
class IdSelector extends SimpleSelector {
  IdSelector(Identifier name, SourceSpan span) : super(name, span);

  visit(TreeVisitor visitor) => visitor.visitIdSelector(this);

  String toString() => "#$name";
}

// .class
class ClassSelector extends SimpleSelector {
  ClassSelector(Identifier name, SourceSpan span) : super(name, span);

  visit(TreeVisitor visitor) => visitor.visitClassSelector(this);

  String toString() => ".$name";
}

// :pseudoClass
class PseudoClassSelector extends SimpleSelector {
  PseudoClassSelector(Identifier name, SourceSpan span) :
      super(name, span);

  visit(TreeVisitor visitor) => visitor.visitPseudoClassSelector(this);

  String toString() => ":$name";
}

// ::pseudoElement
class PseudoElementSelector extends SimpleSelector {
  PseudoElementSelector(Identifier name, SourceSpan span) :
      super(name, span);

  visit(TreeVisitor visitor) => visitor.visitPseudoElementSelector(this);

  String toString() => "::$name";
}

// TODO(terry): Implement
// NOT
class NotSelector extends SimpleSelector {
  NotSelector(String name, SourceSpan span) : super(name, span);

  visit(TreeVisitor visitor) => visitor.visitNotSelector(this);
}

class Stylesheet extends Node {
  // TODO(terry): Cleanup create explict top level e.g., List<RuleSet> rulesets,
  //              etc.  This will allow us to get the proper type inference.
  //              When done cleanup test/compiler_test.dart to remove types
  //              as we drill into the top level.
  /** Contains charset, ruleset, directives (media, page, etc.). */
  List<Node> _topLevels;

  Stylesheet(this._topLevels, SourceSpan span) : super(span) {
    for (final node in _topLevels) {
      assert(node is TopLevelProduction || node is Directive);
    }
  }

  /** Selectors only in this tree. */
  Stylesheet.selector(this._topLevels, SourceSpan span) : super(span);

  visit(TreeVisitor visitor) => visitor.visitStylesheet(this);

  List<Node> get topLevels => _topLevels;

  String toString() {
    StringBuffer buff = new StringBuffer();
    for (final topLevel in _topLevels) {
      buff.add(topLevel.toString());
    }
    return buff.toString();
  }

  /** A multiline string showing the node and its children. */
  String toDebugString() {
    var to = new TreeOutput();
    var tp = new TreePrinter(to);
    this.visit(tp);
    return to.buf.toString();
  }
}

class TopLevelProduction extends Node {
  TopLevelProduction(SourceSpan span) : super(span);

  visit(TreeVisitor visitor) => visitor.visitTopLevelProduction(this);

  String toString() => "TopLevelProduction";
}

class RuleSet extends TopLevelProduction {
  SelectorGroup _selectorGroup;
  DeclarationGroup _declarationGroup;

  RuleSet(this._selectorGroup, this._declarationGroup, SourceSpan span) :
      super(span);

  SelectorGroup get selectorGroup => _selectorGroup;
  DeclarationGroup get declarationGroup => _declarationGroup;

  visit(TreeVisitor visitor) => visitor.visitRuleSet(this);

  String toString() => "\n${_selectorGroup} {\n${_declarationGroup}}\n";
}

class Directive extends Node {
  Directive(SourceSpan span) : super(span);

  String toString() => "Directive";

  bool get isBuiltIn => true;       // Known CSS directive?
  bool get isExtension => false;    // SCSS extension?

  visit(TreeVisitor visitor) => visitor.visitDirective(this);
}

class ImportDirective extends Directive {
  String _import;
  List<String> _media;

  ImportDirective(this._import, this._media, SourceSpan span) :
      super(span);

  visit(TreeVisitor visitor) => visitor.visitImportDirective(this);

  String toString() {
    StringBuffer buff = new StringBuffer();

    buff.add('@import url(${_import})');

    int idx = 0;
    for (final medium in _media) {
      buff.add(idx++ == 0 ? ' $medium' : ',$medium');
    }
    buff.add('\n');

    return buff.toString();
  }
}

class MediaDirective extends Directive {
  List<String> _media;
  RuleSet _ruleset;

  MediaDirective(this._media, this._ruleset, SourceSpan span) :
      super(span);

  visit(TreeVisitor visitor) => visitor.visitMediaDirective(this);

  String toString() {
    StringBuffer buff = new StringBuffer();

    buff.add('@media');
    int idx = 0;
    for (var medium in _media) {
      buff.add(idx++ == 0 ? ' $medium' : ',$medium');
    }
    buff.add(' {\n');
    buff.add(_ruleset.toString());
    buff.add('\n\}\n');

    return buff.toString();
  }
}

class PageDirective extends Directive {
  String _pseudoPage;
  DeclarationGroup _decls;

  PageDirective(this._pseudoPage, this._decls, SourceSpan span) :
    super(span);

  visit(TreeVisitor visitor) => visitor.visitPageDirective(this);

  // @page : pseudoPage {
  //    decls
  // }
  String toString() {
    StringBuffer buff = new StringBuffer();

    buff.add('@page ');
    if (_pseudoPage != null) {
      buff.add(': ${_pseudoPage} ');
    }
    buff.add('{\n${_decls.toString()}\n}\n');

    return buff.toString();
  }
}

class KeyFrameDirective extends Directive {
  var _name;
  List<KeyFrameBlock> _blocks;

  KeyFrameDirective(this._name, SourceSpan span) :
      _blocks = [], super(span);

  add(KeyFrameBlock block) {
    _blocks.add(block);
  }

  String get name => _name;

  visit(TreeVisitor visitor) => visitor.visitKeyFrameDirective(this);

  String toString() {
    StringBuffer buff = new StringBuffer();
    buff.add('@-webkit-keyframes ${_name} {\n');
    for (final block in _blocks) {
      buff.add(block.toString());
    }
    buff.add('}\n');
    return buff.toString();
  }
}

class KeyFrameBlock extends Expression {
  Expressions _blockSelectors;
  DeclarationGroup _declarations;

  KeyFrameBlock(this._blockSelectors, this._declarations, SourceSpan span):
      super(span);

  visit(TreeVisitor visitor) => visitor.visitKeyFrameBlock(this);

  String toString() {
    StringBuffer buff = new StringBuffer();
    buff.add('  ${_blockSelectors.toString()} {\n');
    buff.add(_declarations.toString());
    buff.add('  }\n');
    return buff.toString();
  }
}

// TODO(terry): TBD
class FontFaceDirective extends Directive {
  List<Declaration> _declarations;

  FontFaceDirective(this._declarations, SourceSpan span) : super(span);

  visit(TreeVisitor visitor) => visitor.visitFontFaceDirective(this);

  String toString() {
    return "TO BE DONE";
  }
}

class IncludeDirective extends Directive {
  String _include;
  Stylesheet _stylesheet;

  IncludeDirective(this._include, this._stylesheet, SourceSpan span) :
      super(span);

  visit(TreeVisitor visitor) => visitor.visitIncludeDirective(this);

  bool get isBuiltIn => false;
  bool get isExtension => true;

  Stylesheet get styleSheet => _stylesheet;

  String toString() {
    StringBuffer buff = new StringBuffer();
    buff.add('/****** @include ${_include} ******/\n');
    buff.add(_stylesheet != null ? _stylesheet.toString() : '// <EMPTY>');
    buff.add('/****** End of ${_include} ******/\n\n');
    return buff.toString();
  }
}

class StyletDirective extends Directive {
  String _dartClassName;
  List<RuleSet> _rulesets;

  StyletDirective(this._dartClassName, this._rulesets, SourceSpan span) :
      super(span);

  bool get isBuiltIn => false;
  bool get isExtension => true;

  String get dartClassName => _dartClassName;
  List<RuleSet> get rulesets => _rulesets;

  visit(TreeVisitor visitor) => visitor.visitStyletDirective(this);

  // TODO(terry): Output Dart class
  String toString() => '/* @stylet export as ${_dartClassName} */\n';
}

class Declaration extends Node {
  Identifier _property;
  Expression _expression;
  /** Style exposed to Dart. */
  var _dart;
  bool _important;

  Declaration(this._property, this._expression, this._dart, SourceSpan span) :
      _important = false, super(span);

  String get property => _property.name;
  Expression get expression => _expression;

  bool get hasDartStyle => _dart != null;
  get dartStyle => _dart;
  set dartStyle(var dStyle) {
    _dart = dStyle;
  }

  bool get important => _important;
  set important(bool value) => _important = value;
  String importantAsString() => _important ? ' !important' : '';

  visit(TreeVisitor visitor) => visitor.visitDeclaration(this);

  String toString() =>
      "${_property.name}: ${_expression.toString()}${importantAsString()}";
}

class DeclarationGroup extends Node {
  List<Declaration> _declarations;

  DeclarationGroup(this._declarations, SourceSpan span) : super(span);

  List<Declaration> get declarations => _declarations;

  visit(TreeVisitor visitor) => visitor.visitDeclarationGroup(this);

  String toString() {
    StringBuffer buff = new StringBuffer();
    int idx = 0;
    for (final declaration in _declarations) {
      buff.add("  ${declaration.toString()};\n");
    }
    return buff.toString();
  }
}

class OperatorSlash extends Expression {
  OperatorSlash(SourceSpan span) : super(span);

  visit(TreeVisitor visitor) => visitor.visitOperatorSlash(this);

  String toString() => ' /';
}

class OperatorComma extends Expression {
  OperatorComma(SourceSpan span) : super(span);

  visit(TreeVisitor visitor) => visitor.visitOperatorComma(this);

  String toString() => ',';
}

class LiteralTerm extends Expression {
  var _value;
  String _text;

  LiteralTerm(this._value, this._text, SourceSpan span) : super(span);

  get value => _value;
  String get text => _text;

  visit(TreeVisitor visitor) => visitor.visitLiteralTerm(this);

  String toString() => _text;
}

class NumberTerm extends LiteralTerm {
  NumberTerm(var value, String t, SourceSpan span) : super(value, t, span);

  visit(TreeVisitor visitor) => visitor.visitNumberTerm(this);
}

class UnitTerm extends LiteralTerm {
  int _unit;

  UnitTerm(var value, String t, SourceSpan span, this._unit) :
      super(value, t, span);

  int get unit => _unit;

  visit(TreeVisitor visitor) => visitor.visitUnitTerm(this);

  String toString() => '${text}${unitToString()}';
  String unitToString() => TokenKind.unitToString(_unit);
}

class LengthTerm extends UnitTerm {
  LengthTerm(var value, String t, SourceSpan span,
      [int unit = TokenKind.UNIT_LENGTH_PX]) : super(value, t, span, unit) {
    assert(this._unit == TokenKind.UNIT_LENGTH_PX ||
        this._unit == TokenKind.UNIT_LENGTH_CM ||
        this._unit == TokenKind.UNIT_LENGTH_MM ||
        this._unit == TokenKind.UNIT_LENGTH_IN ||
        this._unit == TokenKind.UNIT_LENGTH_PT ||
        this._unit == TokenKind.UNIT_LENGTH_PC);
  }

  visit(TreeVisitor visitor) => visitor.visitLengthTerm(this);
}

class PercentageTerm extends LiteralTerm {
  PercentageTerm(var value, String t, SourceSpan span) :
      super(value, t, span);

  visit(TreeVisitor visitor) => visitor.visitPercentageTerm(this);

  String toString() => '${text}%';

}

class EmTerm extends LiteralTerm {
  EmTerm(var value, String t, SourceSpan span) :
      super(value, t, span);

  visit(TreeVisitor visitor) => visitor.visitEmTerm(this);

  String toString() => '${text}em';
}

class ExTerm extends LiteralTerm {
  ExTerm(var value, String t, SourceSpan span) :
      super(value, t, span);

  visit(TreeVisitor visitor) => visitor.visitExTerm(this);

  String toString() => '${text}ex';
}

class AngleTerm extends UnitTerm {
  AngleTerm(var value, String t, SourceSpan span,
    [int unit = TokenKind.UNIT_LENGTH_PX]) : super(value, t, span, unit) {
    assert(this._unit == TokenKind.UNIT_ANGLE_DEG ||
        this._unit == TokenKind.UNIT_ANGLE_RAD ||
        this._unit == TokenKind.UNIT_ANGLE_GRAD);
  }

  visit(TreeVisitor visitor) => visitor.visitAngleTerm(this);
}

class TimeTerm extends UnitTerm {
  TimeTerm(var value, String t, SourceSpan span,
    [int unit = TokenKind.UNIT_LENGTH_PX]) : super(value, t, span, unit) {
    assert(this._unit == TokenKind.UNIT_ANGLE_DEG ||
        this._unit == TokenKind.UNIT_TIME_MS ||
        this._unit == TokenKind.UNIT_TIME_S);
  }

  visit(TreeVisitor visitor) => visitor.visitTimeTerm(this);
}

class FreqTerm extends UnitTerm {
  FreqTerm(var value, String t, SourceSpan span,
    [int unit = TokenKind.UNIT_LENGTH_PX]) : super(value, t, span, unit) {
    assert(_unit == TokenKind.UNIT_FREQ_HZ || _unit == TokenKind.UNIT_FREQ_KHZ);
  }

  visit(TreeVisitor visitor) => visitor.visitFreqTerm(this);
}

class FractionTerm extends LiteralTerm {
  FractionTerm(var value, String t, SourceSpan span) :
    super(value, t, span);

  visit(TreeVisitor visitor) => visitor.visitFractionTerm(this);

  String toString() => '${text}fr';
}

class UriTerm extends LiteralTerm {
  UriTerm(String value, SourceSpan span) : super(value, value, span);

  visit(TreeVisitor visitor) => visitor.visitUriTerm(this);

  String toString() => 'url(${text})';
}

class HexColorTerm extends LiteralTerm {
  HexColorTerm(var value, String t, SourceSpan span) :
      super(value, t, span);

  visit(TreeVisitor visitor) => visitor.visitHexColorTerm(this);

  String toString() => '#${text}';
}

class FunctionTerm extends LiteralTerm {
  Expressions _params;

  FunctionTerm(var value, String t, this._params, SourceSpan span)
      : super(value, t, span);

  visit(TreeVisitor visitor) => visitor.visitFunctionTerm(this);

  String toString() {
    // TODO(terry): Optimize rgb to a hexcolor.
    StringBuffer buff = new StringBuffer();

    buff.add('${text}(');
    buff.add(_params.toString());
    buff.add(')');

    return buff.toString();
  }
}

class GroupTerm extends Expression {
  List<LiteralTerm> _terms;

  GroupTerm(SourceSpan span) : _terms =  [], super(span);

  add(LiteralTerm term) {
    _terms.add(term);
  }

  visit(TreeVisitor visitor) => visitor.visitGroupTerm(this);

  String toString() {
    StringBuffer buff = new StringBuffer();
    buff.add('(');
    int idx = 0;
    for (final term in _terms) {
      if (idx++ > 0) {
        buff.add(' ');
      }
      buff.add(term.toString());
    }
    buff.add(')');
    return buff.toString();
  }
}

class ItemTerm extends NumberTerm {
  ItemTerm(var value, String t, SourceSpan span) : super(value, t, span);

  visit(TreeVisitor visitor) => visitor.visitItemTerm(this);

  String toString() => '[${text}]';
}

class Expressions extends Expression {
  List<Expression> _expressions;

  Expressions(SourceSpan span): super(span), _expressions = [];

  add(Expression expression) {
    _expressions.add(expression);
  }

  List<Expression> get expressions => _expressions;

  visit(TreeVisitor visitor) => visitor.visitExpressions(this);

  String toString() {
    StringBuffer buff = new StringBuffer();
    int idx = 0;
    for (final expression in _expressions) {
      // Add space seperator between terms without an operator.
      // TODO(terry): Should have a BinaryExpression to solve this problem.
      if (idx > 0 &&
          !(expression is OperatorComma || expression is OperatorSlash)) {
        buff.add(' ');
      }
      buff.add(expression.toString());
      idx++;
    }
    return buff.toString();
  }
}

class BinaryExpression extends Expression {
  Token op;
  Expression x;
  Expression y;

  BinaryExpression(this.op, this.x, this.y, SourceSpan span): super(span);

  visit(TreeVisitor visitor) => visitor.visitBinaryExpression(this);
}

class UnaryExpression extends Expression {
  Token op;
  Expression self;

  UnaryExpression(this.op, this.self, SourceSpan span): super(span);

  visit(TreeVisitor visitor) => visitor.visitUnaryExpression(this);
}

abstract class DartStyleExpression extends Node {
  static final int unknownType = 0;
  static final int fontStyle = 1;
  static final int marginStyle = 2;
  static final int borderStyle = 3;
  static final int paddingStyle = 4;
  static final int heightStyle = 5;
  static final int widthStyle = 6;

  int _styleType;
  int priority;

  DartStyleExpression(this._styleType, SourceSpan span) : super(span);

  /*
   * Merges give 2 DartStyleExpression (or derived from DartStyleExpression,
   * e.g., FontExpression, etc.) will merge if the two expressions are of the
   * same property name (implies same exact type e.g, FontExpression).
   */
  merged(DartStyleExpression newDartExpr);

  bool get isUnknown => _styleType == 0 || _styleType == null;
  bool get isFont => _styleType == fontStyle;
  bool get isMargin => _styleType == marginStyle;
  bool get isBorder => _styleType == borderStyle;
  bool get isPadding => _styleType == paddingStyle;
  bool get isHeight => _styleType == heightStyle;
  bool get isWidth => _styleType == widthStyle;
  bool get isBoxExpression => isMargin || isBorder || isPadding;

  bool isSame(DartStyleExpression other) => this._styleType == other._styleType;

  visit(TreeVisitor visitor) => visitor.visitDartStyleExpression(this);
}

class FontExpression extends DartStyleExpression {
  Font font;

  //   font-style font-variant font-weight font-size/line-height font-family
  FontExpression(SourceSpan span, {var size, List<String>family,
      int weight, String style, String variant, LineHeight lineHeight}) :
      super(DartStyleExpression.fontStyle, span) {
    // TODO(terry): Only px/pt for now (doesn't even look at the unit).
    assert(size == null || (size != null && size is LengthTerm &&
        size._unit == TokenKind.UNIT_LENGTH_PX ||
        size._unit == TokenKind.UNIT_LENGTH_PT));
    font = new Font(size : size is LengthTerm ? size.value : size,
        family: family, weight: weight, style: style, variant: variant,
        lineHeight: lineHeight);
  }

  merged(FontExpression newFontExpr) {
    if (this.isFont && newFontExpr.isFont) {
      return new FontExpression.merge(this, newFontExpr);
    }

    return null;
  }

  /**
   * Merge the two FontExpression and return the result.
   */
  factory FontExpression.merge(FontExpression x, FontExpression y) {
    return new FontExpression._merge(x, y, y.span);
  }

  FontExpression._merge(FontExpression x, FontExpression y, SourceSpan span) :
      super(DartStyleExpression.fontStyle, span),
      font = new Font.merge(x.font, y.font);

  visit(TreeVisitor visitor) => visitor.visitFontExpression(this);
}

abstract class BoxExpression extends DartStyleExpression {
  BoxEdge boxEdge;

  BoxExpression(int styleType, SourceSpan span, this.boxEdge) :
      super(styleType, span);

  /*
   * Merges give 2 DartStyleExpression (or derived from DartStyleExpression,
   * e.g., FontExpression, etc.) will merge if the two expressions are of the
   * same property name (implies same exact type e.g, FontExpression).
   */
  merged(BoxExpression newDartExpr);

  visit(TreeVisitor visitor) => visitor.visitBoxExpression(this);

  String get formattedBoxEdge {
    if (boxEdge.top == boxEdge.left && boxEdge.top == boxEdge.bottom &&
        boxEdge.top== boxEdge.right) {
      return '.uniform(${boxEdge.top})';
    } else {
      var left = boxEdge.left == null ? 0 : boxEdge.left;
      var top = boxEdge.top == null ? 0 : boxEdge.top;
      var right = boxEdge.right == null ? 0 : boxEdge.right;
      var bottom = boxEdge.bottom == null ? 0 : boxEdge.bottom;
      return '.clockwiseFromTop($top,$right,$bottom,$left)';
    }
  }
}

class MarginExpression extends BoxExpression {
  // TODO(terry): Does auto for margin need to be exposed to Dart UI framework?
  /** Margin expression ripped apart. */
  MarginExpression(SourceSpan span, {num top, num right, num bottom, num left})
      : super(DartStyleExpression.marginStyle, span,
              new BoxEdge(left, top, right, bottom));

  MarginExpression.boxEdge(SourceSpan span, BoxEdge box) :
      super(DartStyleExpression.marginStyle, span, box);

  merged(MarginExpression newMarginExpr) {
    if (this.isMargin && newMarginExpr.isMargin) {
      return new MarginExpression.merge(this, newMarginExpr);
    }

    return null;
  }

  /**
   * Merge the two MarginExpressions and return the result.
   */
  factory MarginExpression.merge(MarginExpression x, MarginExpression y) {
    return new MarginExpression._merge(x, y, y.span);
  }

  MarginExpression._merge(MarginExpression x, MarginExpression y,
      SourceSpan span) :
      super(x._styleType, span, new BoxEdge.merge(x.boxEdge, y.boxEdge));

  visit(TreeVisitor visitor) => visitor.visitMarginExpression(this);

  String toString() => "margin: const BoxEdge$formattedBoxEdge";
}

class BorderExpression extends BoxExpression {
  /** Border expression ripped apart. */
  BorderExpression(SourceSpan span, {num top, num right, num bottom, num left})
      : super(DartStyleExpression.borderStyle, span,
              new BoxEdge(left, top, right, bottom));

  BorderExpression.boxEdge(SourceSpan span, BoxEdge box)
      : super(DartStyleExpression.borderStyle, span, box);

  merged(BorderExpression newBorderExpr) {
    if (this.isBorder && newBorderExpr.isBorder) {
      return new BorderExpression.merge(this, newBorderExpr);
    }

    return null;
  }

  /**
   * Merge the two BorderExpression and return the result.
   */
  factory BorderExpression.merge(BorderExpression x, BorderExpression y) {
    return new BorderExpression._merge(x, y, y.span);
  }

  BorderExpression._merge(BorderExpression x, BorderExpression y,
      SourceSpan span)
      : super(DartStyleExpression.borderStyle, span,
              new BoxEdge.merge(x.boxEdge, y.boxEdge));

  visit(TreeVisitor visitor) => visitor.visitBorderExpression(this);

  String toString() => "border: const BoxEdge$formattedBoxEdge";
}

class HeightExpression extends DartStyleExpression {
  var height;

  HeightExpression(SourceSpan span, this.height) :
      super(DartStyleExpression.heightStyle, span);

  merged(HeightExpression newHeightExpr) {
    if (this.isHeight && newHeightExpr.isHeight) {
      return newHeightExpr;
    }

    return null;
  }

  visit(TreeVisitor visitor) => visitor.visitHeightExpression(this);
}

class WidthExpression extends DartStyleExpression {
  var width;

  WidthExpression(SourceSpan span, this.width) :
      super(DartStyleExpression.widthStyle, span);

  merged(WidthExpression newWidthExpr) {
    if (this.isWidth && newWidthExpr.isWidth) {
      return newWidthExpr;
    }

    return null;
  }

  visit(TreeVisitor visitor) => visitor.visitWidthExpression(this);
}

class PaddingExpression extends BoxExpression {
  /** Padding expression ripped apart. */
  PaddingExpression(SourceSpan span, {num top, num right, num bottom, num left})
      : super(DartStyleExpression.paddingStyle, span,
              new BoxEdge(left, top, right, bottom));

  PaddingExpression.boxEdge(SourceSpan span, BoxEdge box)
      : super(DartStyleExpression.paddingStyle, span, box);

  merged(PaddingExpression newPaddingExpr) {
    if (this.isPadding && newPaddingExpr.isPadding) {
      return new PaddingExpression.merge(this, newPaddingExpr);
    }

    return null;
  }

  /**
   * Merge the two PaddingExpression and return the result.
   */
  factory PaddingExpression.merge(PaddingExpression x, PaddingExpression y) {
    return new PaddingExpression._merge(x, y, y.span);
  }

  PaddingExpression._merge(PaddingExpression x, PaddingExpression y,
      SourceSpan span) :
      super(DartStyleExpression.paddingStyle, span,
            new BoxEdge.merge(x.boxEdge, y.boxEdge));

  visit(TreeVisitor visitor) => visitor.visitPaddingExpression(this);

  String toString() => "padding: const BoxEdge$formattedBoxEdge";
}

abstract class TreeVisitor {
  void visitCssComment(CssComment node);
  void visitCommentDefinition(CommentDefinition node);
  void visitStylesheet(Stylesheet node);
  void visitTopLevelProduction(TopLevelProduction node);
  void visitDirective(Directive node);
  void visitMediaDirective(MediaDirective node);
  void visitPageDirective(PageDirective node);
  void visitImportDirective(ImportDirective node);
  void visitKeyFrameDirective(KeyFrameDirective node);
  void visitKeyFrameBlock(KeyFrameBlock node);
  void visitFontFaceDirective(FontFaceDirective node);
  void visitIncludeDirective(IncludeDirective node);
  void visitStyletDirective(StyletDirective node);

  void visitRuleSet(RuleSet node);
  void visitDeclarationGroup(DeclarationGroup node);
  void visitDeclaration(Declaration node);
  void visitSelectorGroup(SelectorGroup node);
  void visitSelector(Selector node);
  void visitSimpleSelectorSequence(SimpleSelectorSequence node);
  void visitSimpleSelector(SimpleSelector node);
  void visitElementSelector(ElementSelector node);
  void visitNamespaceSelector(NamespaceSelector node);
  void visitAttributeSelector(AttributeSelector node);
  void visitIdSelector(IdSelector node);
  void visitClassSelector(ClassSelector node);
  void visitPseudoClassSelector(PseudoClassSelector node);
  void visitPseudoElementSelector(PseudoElementSelector node);
  void visitNotSelector(NotSelector node);

  void visitLiteralTerm(LiteralTerm node);
  void visitHexColorTerm(HexColorTerm node);
  void visitNumberTerm(NumberTerm node);
  void visitUnitTerm(UnitTerm node);
  void visitLengthTerm(LengthTerm node);
  void visitPercentageTerm(PercentageTerm node);
  void visitEmTerm(EmTerm node);
  void visitExTerm(ExTerm node);
  void visitAngleTerm(AngleTerm node);
  void visitTimeTerm(TimeTerm node);
  void visitFreqTerm(FreqTerm node);
  void visitFractionTerm(FractionTerm node);
  void visitUriTerm(UriTerm node);
  void visitFunctionTerm(FunctionTerm node);
  void visitGroupTerm(GroupTerm node);
  void visitItemTerm(ItemTerm node);
  void visitOperatorSlash(OperatorSlash node);
  void visitOperatorComma(OperatorComma node);

  void visitExpressions(Expressions node);
  void visitBinaryExpression(BinaryExpression node);
  void visitUnaryExpression(UnaryExpression node);

  void visitIdentifier(Identifier node);
  void visitWildcard(Wildcard node);

  // TODO(terry): Defined for ../tree.dart.
  void visitTypeReference(TypeReference node);

  void visitDartStyleExpression(DartStyleExpression node);
  void visitFontExpression(FontExpression node);
  void visitBoxExpression(BoxExpression node);
  void visitMarginExpression(MarginExpression node);
  void visitBorderExpression(BorderExpression node);
  void visitHeightExpression(HeightExpression node);
  void visitPaddingExpression(PaddingExpression node);
  void visitWidthExpression(WidthExpression node);
}

class TreePrinter implements TreeVisitor {
  var output;
  TreePrinter(this.output) { output.printer = this; }

  void visitStylesheet(Stylesheet node) {
    output.heading('Stylesheet', node.span);
    output.depth++;
    output.writeNodeList('productions', node._topLevels);
    output.depth--;
  }

  void visitTopLevelProduction(TopLevelProduction node) {
    output.heading('TopLevelProduction', node.span);
  }

  void visitDirective(Directive node) {
    output.heading('Directive', node.span);
  }

  void visitCssComment(CssComment node) {
    output.heading('Comment', node.span);
    output.depth++;
    output.writeValue('comment value', node.comment);
    output.depth--;
  }

  void visitCommentDefinition(CommentDefinition node) {
    output.heading('CommentDefinition (CDO/CDC)', node.span);
    output.depth++;
    output.writeValue('comment value', node.comment);
    output.depth--;
  }

  void visitMediaDirective(MediaDirective node) {
    output.heading('MediaDirective', node.span);
    output.depth++;
    output.writeNodeList('media', node._media);
    visitRuleSet(node._ruleset);
    output.depth--;
  }

  void visitPageDirective(PageDirective node) {
    output.heading('PageDirective', node.span);
    output.depth++;
    output.writeValue('pseudo page', node._pseudoPage);
    visitDeclarationGroup(node._decls);
    output.depth;
}

  void visitImportDirective(ImportDirective node) {
    output.heading('ImportDirective', node.span);
    output.depth++;
    output.writeValue('import', node._import);
    output.writeNodeList('media', node._media);
    output.depth--;
  }

  void visitKeyFrameDirective(KeyFrameDirective node) {
    output.heading('KeyFrameDirective', node.span);
    output.depth++;
    output.writeValue('name', node._name);
    output.writeNodeList('blocks', node._blocks);
    output.depth--;
  }

  void visitKeyFrameBlock(KeyFrameBlock node) {
    output.heading('KeyFrameBlock', node.span);
    output.depth++;
    visitExpressions(node._blockSelectors);
    visitDeclarationGroup(node._declarations);
    output.depth--;
  }

  void visitFontFaceDirective(FontFaceDirective node) {
    // TODO(terry): To Be Implemented
  }

  void visitIncludeDirective(IncludeDirective node) {
    output.heading('IncludeDirective', node.span);
    output.writeValue('include', node._include);
    output.depth++;
    if (node._stylesheet != null) {
      visitStylesheet(node._stylesheet);
    } else {
      output.writeValue('StyleSheet', '<EMPTY>');
    }
    output.depth--;
  }

  void visitStyletDirective(StyletDirective node) {
    output.heading('StyletDirective', node.span);
    output.writeValue('dartClassName', node._dartClassName);
    output.depth++;
    output.writeNodeList('rulesets', node._rulesets);
    output.depth--;
}

  void visitRuleSet(RuleSet node) {
    output.heading('Ruleset', node.span);
    output.depth++;
    visitSelectorGroup(node._selectorGroup);
    visitDeclarationGroup(node._declarationGroup);
    output.depth--;
  }

  void visitDeclarationGroup(DeclarationGroup node) {
    output.heading('DeclarationGroup', node.span);
    output.depth++;
    output.writeNodeList('declarations', node._declarations);
    output.depth--;
  }

  void visitDeclaration(Declaration node) {
    output.heading('Declaration', node.span);
    output.depth++;
    output.write('property');
    visitIdentifier(node._property);
    output.writeNode('expression', node._expression);
    if (node.important) {
      output.writeValue('!important', 'true');
    }
    output.depth--;
  }

  void visitSelectorGroup(SelectorGroup node) {
    output.heading('Selector Group', node.span);
    output.depth++;
    output.writeNodeList('selectors', node.selectors);
    output.depth--;
  }

  void visitSelector(Selector node) {
    output.heading('Selector', node.span);
    output.depth++;
    output.writeNodeList('simpleSelectorsSequences',
        node._simpleSelectorSequences);
    output.depth--;
  }

  void visitSimpleSelectorSequence(SimpleSelectorSequence node) {
    output.heading('SimpleSelectorSequence', node.span);
    output.depth++;
    if (node.isCombinatorNone()) {
      output.writeValue('combinator', "NONE");
    } else if (node.isCombinatorDescendant()) {
      output.writeValue('combinator', "descendant");
    } else if (node.isCombinatorPlus()) {
      output.writeValue('combinator', "+");
    } else if (node.isCombinatorGreater()) {
      output.writeValue('combinator', ">");
    } else if (node.isCombinatorTilde()) {
      output.writeValue('combinator', "~");
    } else {
      output.writeValue('combinator', "ERROR UNKNOWN");
    }

    var selector = node._selector;
    if (selector is NamespaceSelector) {
      visitNamespaceSelector(selector);
    } else if (selector is ElementSelector) {
      visitElementSelector(selector);
    } else if (selector is IdSelector) {
      visitIdSelector(selector);
    } else if (selector is ClassSelector) {
      visitClassSelector(selector);
    } else if (selector is PseudoClassSelector) {
      visitPseudoClassSelector(selector);
    } else if (selector is PseudoElementSelector) {
      visitPseudoElementSelector(selector);
    } else if (selector is NotSelector) {
      visitNotSelector(selector);
    } else if (selector is AttributeSelector) {
      visitAttributeSelector(selector);
    } else {
      output.heading('SimpleSelector', selector.span);
      output.depth++;
      visitSimpleSelector(selector);
      output.depth--;
    }

    output.depth--;
  }

  void visitSimpleSelector(SimpleSelector node) {
    visitIdentifier(node._name);
  }

  void visitNamespaceSelector(NamespaceSelector node) {
    output.heading('Namespace Selector', node.span);
    output.depth++;

    var namespace = node._namespace;
    if (namespace is Identifier) {
      visitIdentifier(namespace);
    } else if (namespace is Wildcard) {
      visitWildcard(namespace);
    } else {
      output.writeln("NULL");
    }

    visitSimpleSelector(node.nameAsSimpleSelector);
    output.depth--;
  }

  void visitElementSelector(ElementSelector node) {
    output.heading('Element Selector', node.span);
    output.depth++;
    visitSimpleSelector(node);
    output.depth--;
  }

  void visitAttributeSelector(AttributeSelector node) {
    output.heading('AttributeSelector', node.span);
    output.depth++;
    visitSimpleSelector(node);
    String tokenStr = node.matchOperatorAsTokenString();
    output.writeValue('operator', '${node.matchOperator()} (${tokenStr})');
    output.writeValue('value', node.valueToString());
    output.depth--;
  }

  void visitIdSelector(IdSelector node) {
    output.heading('Id Selector', node.span);
    output.depth++;
    visitSimpleSelector(node);
    output.depth--;
  }

  void visitClassSelector(ClassSelector node) {
    output.heading('Class Selector', node.span);
    output.depth++;
    visitSimpleSelector(node);
    output.depth--;
  }

  void visitPseudoClassSelector(PseudoClassSelector node) {
    output.heading('Pseudo Class Selector', node.span);
    output.depth++;
    visitSimpleSelector(node);
    output.depth--;
  }

  void visitPseudoElementSelector(PseudoElementSelector node) {
    output.heading('Pseudo Element Selector', node.span);
    output.depth++;
    visitSimpleSelector(node);
    output.depth--;
  }

  void visitNotSelector(NotSelector node) {
    visitSimpleSelector(node);
    output.depth++;
    output.heading('Not Selector', node.span);
    output.depth--;
  }

  void visitLiteralTerm(LiteralTerm node) {
    output.heading('LiteralTerm', node.span);
    output.depth++;
    output.writeValue('value', node.text);
    output.depth--;
 }

  void visitHexColorTerm(HexColorTerm node) {
    output.heading('HexColorTerm', node.span);
    output.depth++;
    output.writeValue('hex value', node.text);
    output.writeValue('decimal value', node.value);
    output.depth--;
  }

  void visitNumberTerm(NumberTerm node) {
    output.heading('NumberTerm', node.span);
    output.depth++;
    output.writeValue('value', node.text);
    output.depth--;
  }

  void visitUnitTerm(UnitTerm node) {
    String unitValue;

    output.depth++;
    output.writeValue('value', node.text);
    output.writeValue('unit', node.unitToString());
    output.depth--;
  }

  void visitLengthTerm(LengthTerm node) {
    output.heading('LengthTerm', node.span);
    visitUnitTerm(node);
  }

  void visitPercentageTerm(PercentageTerm node) {
    output.heading('PercentageTerm', node.span);
    output.depth++;
    visitLiteralTerm(node);
    output.depth--;
  }

  void visitEmTerm(EmTerm node) {
    output.heading('EmTerm', node.span);
    output.depth++;
    visitLiteralTerm(node);
    output.depth--;
  }

  void visitExTerm(ExTerm node) {
    output.heading('ExTerm', node.span);
    output.depth++;
    visitLiteralTerm(node);
    output.depth--;
  }

  void visitAngleTerm(AngleTerm node) {
    output.heading('AngleTerm', node.span);
    visitUnitTerm(node);
  }

  void visitTimeTerm(TimeTerm node) {
    output.heading('TimeTerm', node.span);
    visitUnitTerm(node);
  }

  void visitFreqTerm(FreqTerm node) {
    output.heading('FreqTerm', node.span);
    visitUnitTerm(node);
  }

  void visitFractionTerm(FractionTerm node) {
    output.heading('FractionTerm', node.span);
    output.depth++;
    visitLiteralTerm(node);
    output.depth--;
  }

  void visitUriTerm(UriTerm node) {
    output.heading('UriTerm', node.span);
    output.depth++;
    visitLiteralTerm(node);
    output.depth--;
  }

  void visitFunctionTerm(FunctionTerm node) {
    output.heading('FunctionTerm', node.span);
    output.depth++;
    visitLiteralTerm(node);
    visitExpressions(node._params);
    output.depth--;
  }

  void visitGroupTerm(GroupTerm node) {
    output.heading('GroupTerm', node.span);
    output.depth++;
    output.writeNodeList('grouped terms', node._terms);
    output.depth--;
  }

  void visitItemTerm(ItemTerm node) {
    output.heading('ItemTerm', node.span);
    visitNumberTerm(node);
  }

  void visitOperatorSlash(OperatorSlash node) {
    output.heading('OperatorSlash', node.span);
  }

  void visitOperatorComma(OperatorComma node) {
    output.heading('OperatorComma', node.span);
  }

  void visitExpressions(Expressions node) {
    output.heading('Expressions', node.span);
    output.depth++;
    output.writeNodeList('expressions', node._expressions);
    output.depth--;
  }

  void visitBinaryExpression(BinaryExpression node) {
    output.heading('BinaryExpression', node.span);
    // TODO(terry): TBD
  }

  void visitUnaryExpression(UnaryExpression node) {
    output.heading('UnaryExpression', node.span);
    // TODO(terry): TBD
  }

  void visitIdentifier(Identifier node) {
    output.heading('Identifier(${output.toValue(node.name)})', node.span);
  }

  void visitWildcard(Wildcard node) {
    output.heading('Wildcard(*)', node.span);
  }

  // TODO(terry): Defined for frog/tree.dart.
  void visitTypeReference(TypeReference node) {
    output.heading('Unimplemented');
  }

  void visitDartStyleExpression(DartStyleExpression node) {
    output.heading('DartStyleExpression', node.span);
  }

  void visitFontExpression(FontExpression node) {
    output.heading('Dart Style FontExpression', node.span);
  }

  void visitBoxExpression(BoxExpression node) {
    output.heading('Dart Style BoxExpression', node.span);
  }

  void visitMarginExpression(MarginExpression node) {
    output.heading('Dart Style MarginExpression', node.span);
  }

  void visitBorderExpression(BorderExpression node) {
    output.heading('Dart Style BorderExpression', node.span);
  }

  void visitHeightExpression(HeightExpression node) {
    output.heading('Dart Style HeightExpression', node.span);
  }

  void visitPaddingExpression(PaddingExpression node) {
    output.heading('Dart Style PaddingExpression', node.span);
  }

  void visitWidthExpression(WidthExpression node) {
    output.heading('Dart Style WidthExpression', node.span);
  }
}
