// Copyright (c) 2013, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

part of visitor;

// TODO(terry): Enable class for debug only; when conditional imports enabled.

/** Helper function to dump the CSS AST. */
String treeToDebugString(styleSheet, [bool useSpan = false]) {
  var to = new TreeOutput();
  new _TreePrinter(to, useSpan)..visitTree(styleSheet);
  return to.toString();
}

/** Tree dump for debug output of the CSS AST. */
class _TreePrinter extends Visitor {
  var output;
  final bool useSpan;
  _TreePrinter(this.output, this.useSpan) { output.printer = this; }

  void visitTree(tree) => visitStylesheet(tree);

  void heading(String heading, node) {
    if (useSpan) {
      output.heading(heading, node.span);
    } else {
      output.heading(heading);
    }
  }

  void visitStylesheet(StyleSheet node) {
    heading('Stylesheet', node);
    output.depth++;
    super.visitStyleSheet(node);
    output.depth--;
  }

  void visitTopLevelProduction(TopLevelProduction node) {
    heading('TopLevelProduction', node);
  }

  void visitDirective(Directive node) {
    heading('Directive', node);
  }

  void visitCssComment(CssComment node) {
    heading('Comment', node);
    output.depth++;
    output.writeValue('comment value', node.comment);
    output.depth--;
  }

  void visitCommentDefinition(CommentDefinition node) {
    heading('CommentDefinition (CDO/CDC)', node);
    output.depth++;
    output.writeValue('comment value', node.comment);
    output.depth--;
  }

  void visitMediaExpression(MediaExpression node) {
    heading('MediaExpression', node);
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
    heading('MediaDirective', node);
    output.depth++;
    output.writeNodeList('media queries', node.mediaQueries);
    output.writeNodeList('rule sets', node.rulesets);
    super.visitMediaDirective(node);
    output.depth--;
  }

  void visitPageDirective(PageDirective node) {
    heading('PageDirective', node);
    output.depth++;
    output.writeValue('pseudo page', node._pseudoPage);
    super.visitPageDirective(node);
    output.depth;
}

  void visitImportDirective(ImportDirective node) {
    heading('ImportDirective', node);
    output.depth++;
    output.writeValue('import', node.import);
    super.visitImportDirective(node);
    output.writeNodeList('media', node.mediaQueries);
    output.depth--;
  }

  void visitKeyFrameDirective(KeyFrameDirective node) {
    heading('KeyFrameDirective', node);
    output.depth++;
    output.writeValue('name', node._name);
    output.writeNodeList('blocks', node._blocks);
    output.depth--;
  }

  void visitKeyFrameBlock(KeyFrameBlock node) {
    heading('KeyFrameBlock', node);
    output.depth++;
    super.visitKeyFrameBlock(node);
    output.depth--;
  }

  void visitFontFaceDirective(FontFaceDirective node) {
    // TODO(terry): To Be Implemented
  }

  void visitIncludeDirective(IncludeDirective node) {
    heading('IncludeDirective', node);
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
    heading('StyletDirective', node);
    output.writeValue('dartClassName', node._dartClassName);
    output.depth++;
    output.writeNodeList('rulesets', node._rulesets);
    output.depth--;
  }

  void visitNamespaceDirective(NamespaceDirective node) {
    heading('NamespaceDirective', node);
    output.depth++;
    output.writeValue('prefix', node._prefix);
    output.writeValue('uri', node._uri);
    output.depth--;
  }

  void visitRuleSet(RuleSet node) {
    heading('Ruleset', node);
    output.depth++;
    super.visitRuleSet(node);
    output.depth--;
  }

  void visitDeclarationGroup(DeclarationGroup node) {
    heading('DeclarationGroup', node);
    output.depth++;
    output.writeNodeList('declarations', node._declarations);
    output.depth--;
  }

  void visitMarginGroup(MarginGroup node) {
    heading('MarginGroup', node);
    output.depth++;
    output.writeValue('@directive', node.margin_sym);
    output.writeNodeList('declarations', node._declarations);
    output.depth--;
  }

  void visitDeclaration(Declaration node) {
    heading('Declaration', node);
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
    heading('Selector Group', node);
    output.depth++;
    output.writeNodeList('selectors', node.selectors);
    output.depth--;
  }

  void visitSelector(Selector node) {
    heading('Selector', node);
    output.depth++;
    output.writeNodeList('simpleSelectorsSequences',
        node._simpleSelectorSequences);
    output.depth--;
  }

  void visitSimpleSelectorSequence(SimpleSelectorSequence node) {
    heading('SimpleSelectorSequence', node);
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
    heading('Namespace Selector', node);
    output.depth++;

    super.visitNamespaceSelector(node);

    visitSimpleSelector(node.nameAsSimpleSelector);
    output.depth--;
  }

  void visitElementSelector(ElementSelector node) {
    heading('Element Selector', node);
    output.depth++;
    super.visitElementSelector(node);
    output.depth--;
  }

  void visitAttributeSelector(AttributeSelector node) {
    heading('AttributeSelector', node);
    output.depth++;
    super.visitAttributeSelector(node);
    String tokenStr = node.matchOperatorAsTokenString();
    output.writeValue('operator', '${node.matchOperator()} (${tokenStr})');
    output.writeValue('value', node.valueToString());
    output.depth--;
  }

  void visitIdSelector(IdSelector node) {
    heading('Id Selector', node);
    output.depth++;
    super.visitIdSelector(node);
    output.depth--;
  }

  void visitClassSelector(ClassSelector node) {
    heading('Class Selector', node);
    output.depth++;
    super.visitClassSelector(node);
    output.depth--;
  }

  void visitPseudoClassSelector(PseudoClassSelector node) {
    heading('Pseudo Class Selector', node);
    output.depth++;
    super.visitPseudoClassSelector(node);
    output.depth--;
  }

  void visitPseudoElementSelector(PseudoElementSelector node) {
    heading('Pseudo Element Selector', node);
    output.depth++;
    super.visitPseudoElementSelector(node);
    output.depth--;
  }

  void visitNotSelector(NotSelector node) {
    super.visitNotSelector(node);
    output.depth++;
    heading('Not Selector', node);
    output.depth--;
  }

  void visitLiteralTerm(LiteralTerm node) {
    heading('LiteralTerm', node);
    output.depth++;
    output.writeValue('value', node.text);
    output.depth--;
 }

  void visitHexColorTerm(HexColorTerm node) {
    heading('HexColorTerm', node);
    output.depth++;
    output.writeValue('hex value', node.text);
    output.writeValue('decimal value', node.value);
    output.depth--;
  }

  void visitNumberTerm(NumberTerm node) {
    heading('NumberTerm', node);
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
    heading('LengthTerm', node);
    super.visitLengthTerm(node);
  }

  void visitPercentageTerm(PercentageTerm node) {
    heading('PercentageTerm', node);
    output.depth++;
    super.visitPercentageTerm(node);
    output.depth--;
  }

  void visitEmTerm(EmTerm node) {
    heading('EmTerm', node);
    output.depth++;
    super.visitEmTerm(node);
    output.depth--;
  }

  void visitExTerm(ExTerm node) {
    heading('ExTerm', node);
    output.depth++;
    super.visitExTerm(node);
    output.depth--;
  }

  void visitAngleTerm(AngleTerm node) {
    heading('AngleTerm', node);
    super.visitAngleTerm(node);
  }

  void visitTimeTerm(TimeTerm node) {
    heading('TimeTerm', node);
    super.visitTimeTerm(node);
  }

  void visitFreqTerm(FreqTerm node) {
    heading('FreqTerm', node);
    super.visitFreqTerm(node);
  }

  void visitFractionTerm(FractionTerm node) {
    heading('FractionTerm', node);
    output.depth++;
    super.visitFractionTerm(node);
    output.depth--;
  }

  void visitUriTerm(UriTerm node) {
    heading('UriTerm', node);
    output.depth++;
    super.visitUriTerm(node);
    output.depth--;
  }

  void visitFunctionTerm(FunctionTerm node) {
    heading('FunctionTerm', node);
    output.depth++;
    super.visitFunctionTerm(node);
    output.depth--;
  }

  void visitGroupTerm(GroupTerm node) {
    heading('GroupTerm', node);
    output.depth++;
    output.writeNodeList('grouped terms', node._terms);
    output.depth--;
  }

  void visitItemTerm(ItemTerm node) {
    heading('ItemTerm', node);
    super.visitItemTerm(node);
  }

  void visitOperatorSlash(OperatorSlash node) {
    heading('OperatorSlash', node);
  }

  void visitOperatorComma(OperatorComma node) {
    heading('OperatorComma', node);
  }

  void visitExpressions(Expressions node) {
    heading('Expressions', node);
    output.depth++;
    output.writeNodeList('expressions', node._expressions);
    output.depth--;
  }

  void visitBinaryExpression(BinaryExpression node) {
    heading('BinaryExpression', node);
    // TODO(terry): TBD
  }

  void visitUnaryExpression(UnaryExpression node) {
    heading('UnaryExpression', node);
    // TODO(terry): TBD
  }

  void visitIdentifier(Identifier node) {
    heading('Identifier(${output.toValue(node.name)})', node);
  }

  void visitWildcard(Wildcard node) {
    heading('Wildcard(*)', node);
  }

  void visitDartStyleExpression(DartStyleExpression node) {
    heading('DartStyleExpression', node);
  }

  void visitFontExpression(FontExpression node) {
    heading('Dart Style FontExpression', node);
  }

  void visitBoxExpression(BoxExpression node) {
    heading('Dart Style BoxExpression', node);
  }

  void visitMarginExpression(MarginExpression node) {
    heading('Dart Style MarginExpression', node);
  }

  void visitBorderExpression(BorderExpression node) {
    heading('Dart Style BorderExpression', node);
  }

  void visitHeightExpression(HeightExpression node) {
    heading('Dart Style HeightExpression', node);
  }

  void visitPaddingExpression(PaddingExpression node) {
    heading('Dart Style PaddingExpression', node);
  }

  void visitWidthExpression(WidthExpression node) {
    heading('Dart Style WidthExpression', node);
  }
}
