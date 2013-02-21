// Copyright (c) 2013, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

part of visitor;

// TODO(terry): Enable class for debug only; when conditional imports enabled.

/** Helper function to dump the CSS AST. */
String treeToDebugString(styleSheet) {
  var to = new TreeOutput();
  new _TreePrinter(to)..visitTree(styleSheet);
  return to.toString();
}

/** Tree dump for debug output of the CSS AST. */
class _TreePrinter extends Visitor {
  var output;
  _TreePrinter(this.output) { output.printer = this; }

  void visitTree(tree) => visitStylesheet(tree);

  void visitStylesheet(StyleSheet node) {
    output.heading('Stylesheet', node.span);
    output.depth++;
    super.visitStyleSheet(node);
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

  void visitMediaExpression(MediaExpression node) {
    output.heading('MediaExpression');
    output.writeValue('feature', node.mediaFeature);
    if (node.andOperator) output.writeValue('AND operator', '');
    visitExpressions(node.exprs);
  }

  void visitMediaQueries(MediaQuery query) {
    output.headeing('MediaQueries');
    output.writeValue('unary', query.unary);
    output.writeValue('media type', query.mediaType);
    output.writeNodeList('media expressions', query.expressions);
  }

  void visitMediaDirective(MediaDirective node) {
    output.heading('MediaDirective', node.span);
    output.depth++;
    output.writeNodeList('media queries', node.mediaQueries);
    output.writeNodeList('rule sets', node.rulesets);
    super.visitMediaDirective(node);
    output.depth--;
  }

  void visitPageDirective(PageDirective node) {
    output.heading('PageDirective', node.span);
    output.depth++;
    output.writeValue('pseudo page', node._pseudoPage);
    super.visitPageDirective(node);
    output.depth;
}

  void visitImportDirective(ImportDirective node) {
    output.heading('ImportDirective', node.span);
    output.depth++;
    output.writeValue('import', node.import);
    super.visitImportDirective(node);
    output.writeNodeList('media', node.mediaQueries);
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
    super.visitKeyFrameBlock(node);
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
      super.visitIncludeDirective(node);
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

  void visitNamespaceDirective(NamespaceDirective node) {
    output.heading('NamespaceDirective', node.span);
    output.depth++;
    output.writeValue('prefix', node._prefix);
    output.writeValue('uri', node._uri);
    output.depth--;
  }

  void visitRuleSet(RuleSet node) {
    output.heading('Ruleset', node.span);
    output.depth++;
    super.visitRuleSet(node);
    output.depth--;
  }

  void visitDeclarationGroup(DeclarationGroup node) {
    output.heading('DeclarationGroup', node.span);
    output.depth++;
    output.writeNodeList('declarations', node._declarations);
    output.depth--;
  }

  void visitMarginGroup(MarginGroup node) {
    output.heading('MarginGroup', node.span);
    output.depth++;
    output.writeValue('@directive', node.margin_sym);
    output.writeNodeList('declarations', node._declarations);
    output.depth--;
  }

  void visitDeclaration(Declaration node) {
    output.heading('Declaration', node.span);
    output.depth++;
    output.write('property');
    super.visitDeclaration(node);
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
    if (node.isCombinatorNone) {
      output.writeValue('combinator', "NONE");
    } else if (node.isCombinatorDescendant) {
      output.writeValue('combinator', "descendant");
    } else if (node.isCombinatorPlus) {
      output.writeValue('combinator', "+");
    } else if (node.isCombinatorGreater) {
      output.writeValue('combinator', ">");
    } else if (node.isCombinatorTilde) {
      output.writeValue('combinator', "~");
    } else {
      output.writeValue('combinator', "ERROR UNKNOWN");
    }

    super.visitSimpleSelectorSequence(node);

    output.depth--;
  }

  void visitNamespaceSelector(NamespaceSelector node) {
    output.heading('Namespace Selector', node.span);
    output.depth++;

    super.visitNamespaceSelector(node);

    visitSimpleSelector(node.nameAsSimpleSelector);
    output.depth--;
  }

  void visitElementSelector(ElementSelector node) {
    output.heading('Element Selector', node.span);
    output.depth++;
    super.visitElementSelector(node);
    output.depth--;
  }

  void visitAttributeSelector(AttributeSelector node) {
    output.heading('AttributeSelector', node.span);
    output.depth++;
    super.visitAttributeSelector(node);
    String tokenStr = node.matchOperatorAsTokenString();
    output.writeValue('operator', '${node.matchOperator()} (${tokenStr})');
    output.writeValue('value', node.valueToString());
    output.depth--;
  }

  void visitIdSelector(IdSelector node) {
    output.heading('Id Selector', node.span);
    output.depth++;
    super.visitIdSelector(node);
    output.depth--;
  }

  void visitClassSelector(ClassSelector node) {
    output.heading('Class Selector', node.span);
    output.depth++;
    super.visitClassSelector(node);
    output.depth--;
  }

  void visitPseudoClassSelector(PseudoClassSelector node) {
    output.heading('Pseudo Class Selector', node.span);
    output.depth++;
    super.visitPseudoClassSelector(node);
    output.depth--;
  }

  void visitPseudoElementSelector(PseudoElementSelector node) {
    output.heading('Pseudo Element Selector', node.span);
    output.depth++;
    super.visitPseudoElementSelector(node);
    output.depth--;
  }

  void visitNotSelector(NotSelector node) {
    super.visitNotSelector(node);
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
    super.visitLengthTerm(node);
  }

  void visitPercentageTerm(PercentageTerm node) {
    output.heading('PercentageTerm', node.span);
    output.depth++;
    super.visitPercentageTerm(node);
    output.depth--;
  }

  void visitEmTerm(EmTerm node) {
    output.heading('EmTerm', node.span);
    output.depth++;
    super.visitEmTerm(node);
    output.depth--;
  }

  void visitExTerm(ExTerm node) {
    output.heading('ExTerm', node.span);
    output.depth++;
    super.visitExTerm(node);
    output.depth--;
  }

  void visitAngleTerm(AngleTerm node) {
    output.heading('AngleTerm', node.span);
    super.visitAngleTerm(node);
  }

  void visitTimeTerm(TimeTerm node) {
    output.heading('TimeTerm', node.span);
    super.visitTimeTerm(node);
  }

  void visitFreqTerm(FreqTerm node) {
    output.heading('FreqTerm', node.span);
    super.visitFreqTerm(node);
  }

  void visitFractionTerm(FractionTerm node) {
    output.heading('FractionTerm', node.span);
    output.depth++;
    super.visitFractionTerm(node);
    output.depth--;
  }

  void visitUriTerm(UriTerm node) {
    output.heading('UriTerm', node.span);
    output.depth++;
    super.visitUriTerm(node);
    output.depth--;
  }

  void visitFunctionTerm(FunctionTerm node) {
    output.heading('FunctionTerm', node.span);
    output.depth++;
    super.visitFunctionTerm(node);
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
    super.visitItemTerm(node);
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
