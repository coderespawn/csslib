// Copyright (c) 2013, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

part of visitor;

/**
 * Visitor that produces a formatted string representation of the CSS tree.
 */
class CssPrinter extends Visitor {
  StringBuffer _buff = new StringBuffer();
  bool prettyPrint = true;

  /**
   * Walk the [tree] Stylesheet. [pretty] if true emits line breaks, extra
   * spaces, friendly property values, etc., if false emits compacted output.
   */
  void visitTree(StyleSheet tree, {bool pretty: false}) {
    prettyPrint = pretty;
    _buff = new StringBuffer();
    visitStyleSheet(tree);
  }

  /** Appends [str] to the output buffer. */
  void emit(String str) {
    _buff.write(str);
  }

  /** Returns the output buffer. */
  String toString() => _buff.toString().trim();

  String get _newLine => prettyPrint ? '\n' : ' ';
  String get _sp => prettyPrint ? ' ' : '';

  // TODO(terry): When adding obfuscation we'll need isOptimized (compact w/
  //              obufuscation) and have isTesting (compact no obfuscation) and
  //              isCompact would be !prettyPrint.  We'll need another boolean
  //              flag for obfuscation.
  bool get _isTesting => !prettyPrint;

  void visitCssComment(CssComment node) {
    emit('/* ${node.comment} */');
  }

  void visitCommentDefinition(CommentDefinition node) {
    emit('<!-- ${node.comment} -->');
  }

  void visitMediaExpression(MediaExpression node) {
    emit(node.andOperator ? ' AND ' : ' ');
    emit('(${node.mediaFeature}:');
    visitExpressions(node.exprs);
    emit(')');
  }

  void visitMediaQuery(MediaQuery query) {
    emit('${query.unary}${query.mediaType}');
    for (var expression in query.expressions) {
      visitMediaExpression(expression);
    }
  }

  void emitMediaQueries(queries, [forceSpace = false]) {
    var queriesLen = queries.length;
    for (var idx = 0; idx < queriesLen; idx++) {
      if (!forceSpace && idx == 0) emit(' ');
      if (idx > 0) emit(',');
      var query = queries[idx];
      visitMediaQuery(query);
    }
  }

  void visitMediaDirective(MediaDirective node) {
    emit(' @media');
    emitMediaQueries(node.mediaQueries);
    emit(' {');
    for (var ruleset in node.rulesets) {
      ruleset.visit(this);
    }
    emit('$_newLine\}');
  }

  // @page : pseudoPage {
  //    decls
  // }
  void visitPageDirective(PageDirective node) {
    emit('$_newLine@page');
    if (node.hasIdent || node.hasPseudoPage) {
      if (node.hasIdent) emit(' ');
      emit(node._ident);
      emit(node.hasPseudoPage ? ':${node._pseudoPage}' : '');
    }
    emit(' ');

    var declsMargin = node._declsMargin;
    int declsMarginLength = declsMargin.length;
    for (var idx = 0; idx < declsMarginLength; idx++) {
      if (idx > 0) emit(_newLine);
      emit('{$_newLine');
      declsMargin[idx].visit(this);
      emit('}');
    }
  }

  void visitImportDirective(ImportDirective node) {
    bool isStartingQuote(String ch) => ('\'"'.indexOf(ch) >= 0);

    if (isStartingQuote(node.import)) {
      emit(' @import "${node.import}"');
    } else {
      if (_isTesting) {
        // Emit exactly was we parsed.
        emit(' @import url(${node.import})');
      } else {
        // url(...) isn't needed only a URI can follow an @import directive.
        emit(' @import ${node.import}');
      }
    }
    emitMediaQueries(node.mediaQueries, _isTesting);
    emit(';');
  }

  void visitKeyFrameDirective(KeyFrameDirective node) {
    emit('$_newLine@-webkit-keyframes ');
    node._name.visit(this);
    emit('$_sp{$_newLine');
    for (final block in node._blocks) {
      block.visit(this);
    }
    emit('}');
  }

  void visitKeyFrameBlock(KeyFrameBlock node) {
    emit('$_sp$_sp');
    node._blockSelectors.visit(this);
    emit('$_sp{$_newLine');
    node._declarations.visit(this);
    emit('$_sp$_sp}$_newLine');
  }

  void visitIncludeDirective(IncludeDirective node) {
    emit('/****** @include ${node._include} ******/\n');
    if (node._stylesheet != null) {
      node._stylesheet.visit(this);
    } else {
      emit('// <EMPTY>');
    }
    emit('/****** End of ${node._include} ******/\n\n');
  }

  void visitStyletDirective(StyletDirective node) {
    emit('/* @stylet export as ${node._dartClassName} */\n');
  }

  void visitNamespaceDirective(NamespaceDirective node) {
    bool isStartingQuote(String ch) => ('\'"'.indexOf(ch) >= 0);

    if (isStartingQuote(node._uri)) {
      emit(' @namespace ${node.prefix}"${node._uri}"');
    } else {
      if (_isTesting) {
        // Emit exactly was we parsed.
        emit(' @namespace ${node.prefix}url(${node._uri})');
      } else {
        // url(...) isn't needed only a URI can follow a:
        //    @namespace prefix directive.
        emit(' @namespace ${node.prefix}${node._uri}');
      }
    }
    emit(';');
  }

  void visitRuleSet(RuleSet node) {
    emit("$_newLine");
    node._selectorGroup.visit(this);
    emit(" {$_newLine");
    node._declarationGroup.visit(this);
    emit("}");
  }

  void visitDeclarationGroup(DeclarationGroup node) {
    var declarations = node._declarations;
    var declarationsLength = declarations.length;
    for (var idx = 0; idx < declarationsLength; idx++) {
      if (idx > 0) emit(_newLine);
      emit("$_sp$_sp");
      declarations[idx].visit(this);
      emit(";");
    }
    if (declarationsLength > 0) emit(_newLine);
  }

  void visitMarginGroup(MarginGroup node) {
    var margin_sym_name =
        TokenKind.idToValue(TokenKind.MARGIN_DIRECTIVES, node.margin_sym);

    emit("@$margin_sym_name {$_newLine");

    visitDeclarationGroup(node);

    emit("}$_newLine");
  }

  void visitDeclaration(Declaration node) {
    String importantAsString() => node.important ? '$_sp!important' : '';

    emit("${node._property.name}: ");
    node._expression.visit(this);

    emit("${importantAsString()}");
  }

  void visitSelectorGroup(SelectorGroup node) {
    var selectors = node._selectors;
    var selectorsLength = selectors.length;
    for (var idx = 0; idx < selectorsLength; idx++) {
      if (idx > 0) emit(',$_sp');
      selectors[idx].visit(this);
    }
  }

  void visitSimpleSelectorSequence(SimpleSelectorSequence node) {
    emit('${node._combinatorToString}');
    node._selector.visit(this);
  }

  void visitSimpleSelector(SimpleSelector node) {
    emit(node.name);
  }

  void visitNamespaceSelector(NamespaceSelector node) {
    emit("${node.namespace}|${node.nameAsSimpleSelector.name}");
  }

  void visitElementSelector(ElementSelector node) {
    emit("${node.name}");
  }

  void visitAttributeSelector(AttributeSelector node) {
    emit("[${node.name}${node.matchOperator()}${node.valueToString()}]");
  }

  void visitIdSelector(IdSelector node) {
    emit("#${node.name}");
  }

  void visitClassSelector(ClassSelector node) {
    emit(".${node.name}");
  }

  void visitPseudoClassSelector(PseudoClassSelector node) {
    emit(":${node.name}");
  }

  void visitPseudoElementSelector(PseudoElementSelector node) {
    emit("::${node.name}");
  }

  void visitNotSelector(NotSelector node) {
    // TODO(terry): TBD
  }

  void visitLiteralTerm(LiteralTerm node) {
    emit(node._text);
  }

  void visitHexColorTerm(HexColorTerm node) {
    var mappedName;
    if (_isTesting && (node.value is! BAD_HEX_VALUE)) {
      mappedName = TokenKind.hexToColorName(node.value);
    }
    if (mappedName == null) {
      mappedName = '#${node.text}';
    }

    emit(mappedName);
  }

  void visitNumberTerm(NumberTerm node) {
    visitLiteralTerm(node);
  }

  void visitUnitTerm(UnitTerm node) {
    emit(node.toString());
  }

  void visitLengthTerm(LengthTerm node) {
    emit(node.toString());
  }

  void visitPercentageTerm(PercentageTerm node) {
    emit('${node.text}%');
  }

  void visitEmTerm(EmTerm node) {
    emit('${node.text}em');
  }

  void visitExTerm(ExTerm node) {
    emit('${node.text}ex');
  }

  void visitAngleTerm(AngleTerm node) {
    emit(node.toString());
  }

  void visitTimeTerm(TimeTerm node) {
    emit(node.toString());
  }

  void visitFreqTerm(FreqTerm node) {
    emit(node.toString());
  }

  void visitFractionTerm(FractionTerm node) {
    emit('${node.text}fr');
  }

  void visitUriTerm(UriTerm node) {
    emit('url("${node.text}")');
  }

  void visitResolutionTerm(ResolutionTerm node) {
    emit(node.toString());
  }

  void visitViewportTerm(ViewportTerm node) {
    emit(node.toString());
  }

  void visitFunctionTerm(FunctionTerm node) {
    // TODO(terry): Optimize rgb to a hexcolor.
    emit('${node.text}(');
    node._params.visit(this);
    emit(')');
  }

  void visitGroupTerm(GroupTerm node) {
    emit('(');
    var terms = node._terms;
    var termsLength = terms.length;
    for (var idx = 0; idx < termsLength; idx++) {
      if (idx > 0) emit('$_sp');
      terms[idx].visit(this);
    }
    emit(')');
  }

  void visitItemTerm(ItemTerm node) {
    emit('[${node.text}]');
  }

  void visitOperatorSlash(OperatorSlash node) {
    emit('/');
  }

  void visitOperatorComma(OperatorComma node) {
    emit(',');
  }

  void visitExpressions(Expressions node) {
    var expressions = node._expressions;
    var expressionsLength = expressions.length;
    for (var idx = 0; idx < expressionsLength; idx++) {
      // Add space seperator between terms without an operator.
      // TODO(terry): Should have a BinaryExpression to solve this problem.
      var expression = expressions[idx];
      if (idx > 0 &&
          !(expression is OperatorComma || expression is OperatorSlash)) {
        emit(' ');
      }
      expression.visit(this);
    }
  }

  void visitBinaryExpression(BinaryExpression node) {
    // TODO(terry): TBD
    throw UnimplementedError;
  }

  void visitUnaryExpression(UnaryExpression node) {
    // TODO(terry): TBD
    throw UnimplementedError;
  }

  void visitIdentifier(Identifier node) {
    emit(node.name);
  }

  void visitWildcard(Wildcard node) {
    emit('*');
  }

  void visitDartStyleExpression(DartStyleExpression node) {
    // TODO(terry): TBD
    throw UnimplementedError;
  }
}
