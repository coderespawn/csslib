// Copyright (c) 2012, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library parser;

import 'dart:io' as io;
import 'dart:math' as math;

import 'package:pathos/path.dart' as path;
import 'package:source_maps/span.dart' show File, Span, FileSpan;

import "visitor.dart";
import 'src/messages.dart';
import 'src/options.dart';

part 'src/property.dart';
part 'src/token.dart';
part 'src/tokenizer_base.dart';
part 'src/tokenizer.dart';
part 'src/tokenkind.dart';

/**
 * Parse the [input] CSS stylesheet into a tree. The [input] can be a [String],
 * or [List<int>] of bytes and returns a [StyleSheet] AST.  The optional
 * [errors] list will contain each error/warning as a [Message].
 */
StyleSheet parse(var input, {List errors, List options}) {
  var source = _inputAsString(input);

  if (errors == null) {
    errors = [];
  }

  if (options == null) {
    options = ['--no-colors', 'memory'];
  }
  var opt = PreprocessorOptions.parse(options);
  messages = new Messages(options: opt, printHandler: errors.add);
  return new Parser(new File.text(null, source), source).parse();
}

/**
 * Parse the [input] CSS selector into a tree. The [input] can be a [String],
 * or [List<int>] of bytes and returns a [StyleSheet] AST.  The optional
 * [errors] list will contain each error/warning as a [Message].
 */
StyleSheet selector(var input, {List errors}) {
  var source = _inputAsString(input);

  if (errors == null) {
    errors = [];
  }

  // TODO(terry): Allow options to be passed in too?
  var opt = PreprocessorOptions.parse(['--no-colors', 'memory']);
  messages = new Messages(options: opt, printHandler: (Object obj) {
    errors.add(obj);
  });

  var p = new Parser(new File.text(null, source), source);
  return p.parseSelector();
}

String _inputAsString(var input) {
  String source;

  if (input is String) {
    source = input;
  } else if (input is List<int>) {
    // TODO(terry): The parse function needs an "encoding" argument and will
    //              default to whatever encoding CSS defaults to.
    //
    // Here's some info about CSS encodings:
    // http://www.w3.org/International/questions/qa-css-charset.en.php
    //
    // As JMesserly suggests it will probably need a "preparser" html5lib
    // (encoding_parser.dart) that interprets the bytes as ASCII and scans for
    // @charset. But for now an "encoding" argument would work.  Often the
    // HTTP header will indicate the correct encoding.
    //
    // See encoding helpers at: package:html5lib/lib/src/char_encodings.dart
    // These helpers can decode in different formats given an encoding name
    // (mostly unicode, ascii, windows-1252 which is html5 default encoding).
    source = new String.fromCharCodes(input);
  } else {
    // TODO(terry): Support RandomAccessFile using console.
    throw new ArgumentError("'source' must be a String or "
        "List<int> (of bytes). RandomAccessFile not supported from this "
        "simple interface");
  }

  return source;
}

/**
 * A simple recursive descent parser for CSS.
 */
class Parser {
  String _mainPath;

  Tokenizer tokenizer;

  final String _basePath;               // Base path of CSS file.

  final File file;

  Token _previousToken;
  Token _peekToken;

  Parser(File file, String text, [int start = 0, this._basePath])
      : this.file = file,
        tokenizer = new Tokenizer(file, text, true, start) {
    _peekToken = tokenizer.next();
  }

  /** Main entry point for parsing an entire CSS file. */
  StyleSheet parse() {
    List<TreeNode> productions = [];

    int start = _peekToken.start;
    while (!_maybeEat(TokenKind.END_OF_FILE) && !_peekKind(TokenKind.RBRACE)) {
      // TODO(terry): Need to handle charset, import, media and page.
      var directive = processDirective();
      if (directive != null) {
        productions.add(directive);
        _maybeEat(TokenKind.SEMICOLON);
      } else {
        RuleSet ruleset = processRuleSet();
        if (ruleset != null) {
          productions.add(ruleset);
        } else {
          break;
        }
      }
    }

    return new StyleSheet(productions, _makeSpan(start));
  }

  /** Main entry point for parsing a simple selector sequence. */
  StyleSheet parseSelector() {
    List<TreeNode> productions = [];

    int start = _peekToken.start;
    while (!_maybeEat(TokenKind.END_OF_FILE) && !_peekKind(TokenKind.RBRACE)) {
      var selector = processSelector();
      if (selector != null) {
        productions.add(selector);
      }
    }

    return new StyleSheet.selector(productions, _makeSpan(start));
  }

  /** Generate an error if [source] has not been completely consumed. */
  void checkEndOfFile() {
    _eat(TokenKind.END_OF_FILE);
  }

  /** Guard to break out of parser when an unexpected end of file is found. */
  // TODO(jimhug): Failure to call this method can lead to inifinite parser
  //   loops.  Consider embracing exceptions for more errors to reduce
  //   the danger here.
  bool isPrematureEndOfFile() {
    if (_maybeEat(TokenKind.END_OF_FILE)) {
      _error('unexpected end of file', _peekToken.span);
      return true;
    } else {
      return false;
    }
  }

  ///////////////////////////////////////////////////////////////////
  // Basic support methods
  ///////////////////////////////////////////////////////////////////
  int _peek() {
    return _peekToken.kind;
  }

  Token _next() {
    _previousToken = _peekToken;
    _peekToken = tokenizer.next();
    return _previousToken;
  }

  bool _peekKind(int kind) {
    return _peekToken.kind == kind;
  }

  /* Is the next token a legal identifier?  This includes pseudo-keywords. */
  bool _peekIdentifier() {
    return TokenKind.isIdentifier(_peekToken.kind);
  }

  bool _maybeEat(int kind) {
    if (_peekToken.kind == kind) {
      _previousToken = _peekToken;
      _peekToken = tokenizer.next();
      return true;
    } else {
      return false;
    }
  }

  void _eat(int kind) {
    if (!_maybeEat(kind)) {
      _errorExpected(TokenKind.kindToString(kind));
    }
  }

  void _eatSemicolon() {
    _eat(TokenKind.SEMICOLON);
  }

  void _errorExpected(String expected) {
    var tok = _next();
    var message;
    try {
      message = 'expected $expected, but found $tok';
    } catch (e) {
      message = 'parsing error expected $expected';
    }
    _error(message, tok.span);
  }

  void _error(String message, Span location) {
    if (location == null) {
      location = _peekToken.span;
    }
    messages.error(message, location);
  }

  void _warning(String message, Span location) {
    if (location == null) {
      location = _peekToken.span;
    }
    messages.warning(message, location);
  }

  Span _makeSpan(int start) {
    // TODO(terry): there are places where we are creating spans before we eat
    // the tokens, so using _previousToken.end is not always valid.
    var end = _previousToken.end >= start ? _previousToken.end : _peekToken.end;
    return file.span(start, end);
  }

  ///////////////////////////////////////////////////////////////////
  // Top level productions
  ///////////////////////////////////////////////////////////////////

  // Templates are @{selectors} single line nothing else.
  SelectorGroup parseTemplate() {
    SelectorGroup selectorGroup = null;
    if (!isPrematureEndOfFile()) {
      selectorGroup = templateExpression();
    }

    return selectorGroup;
  }

  /*
   * Expect @{css_expression}
   */
  templateExpression() {
    List<Selector> selectors = [];

    int start = _peekToken.start;

    _eat(TokenKind.AT);
    _eat(TokenKind.LBRACE);

    selectors.add(processSelector());
    SelectorGroup group = new SelectorGroup(selectors, _makeSpan(start));

    _eat(TokenKind.RBRACE);

    return group;
  }

  ///////////////////////////////////////////////////////////////////
  // Productions
  ///////////////////////////////////////////////////////////////////

  /**
   * The media_query_list production below replaces the media_list production
   * from CSS2 the new grammar is:
   *
   *   media_query_list
   *    : S* [media_query [ ',' S* media_query ]* ]?
   *   media_query
   *    : [ONLY | NOT]? S* media_type S* [ AND S* expression ]*
   *    | expression [ AND S* expression ]*
   *   media_type
   *    : IDENT
   *   expression
   *    : '(' S* media_feature S* [ ':' S* expr ]? ')' S*
   *   media_feature
   *    : IDENT
   */
  List<MediaQuery> processMediaQueryList() {
    var mediaQueries = [];

    var mediaQuery;
    do {
      mediaQuery = processMediaQuery();
      if (mediaQuery != null) {
        mediaQueries.add(mediaQuery);
        if (!_maybeEat(TokenKind.COMMA)) {
          // No more media types exit now.
          break;
        }
      }
    } while (mediaQuery != null);

    return mediaQueries;
  }

  MediaQuery processMediaQuery() {
    // Grammar: [ONLY | NOT]? S* media_type S*
    //          [ AND S* MediaExpr ]* | MediaExpr [ AND S* MediaExpr ]*

    int start = _peekToken.start;

    // Is it a unary media operator?
    var op = _peekToken.text;
    var opLen = op.length;
    var unaryOp = TokenKind.matchMediaOperator(op, 0, opLen);
    if (unaryOp == -1 ||
        unaryOp == TokenKind.MEDIA_OP_NOT ||
        unaryOp == TokenKind.MEDIA_OP_ONLY) {

      if (_peekIdentifier()) {
        var type = identifier();           // Media type.
        var exprs = [];

        if (unaryOp == -1 || unaryOp == TokenKind.MEDIA_OP_AND) {
          while (true) {
            op = _peekToken.text;
            opLen = op.length;
            op = TokenKind.matchMediaOperator(op, 0, opLen);
            var andOp = op == TokenKind.MEDIA_OP_AND;
            if (andOp) _next();
            var expr = processMediaExpression(andOp);
            if (expr != null) exprs.add(expr);
            if (!andOp) break;
          }
        }

        return new MediaQuery(unaryOp, type, exprs, _makeSpan(start));
      }
    } else if (messages.options.checked) {
      _warning("Only unary operators NOT and ONLY allowed", _makeSpan(start));
    }
  }

  MediaExpression processMediaExpression([bool andOperator = false]) {
    int start = _peekToken.start;

    // Grammar: '(' S* media_feature S* [ ':' S* expr ]? ')' S*
    if (_maybeEat(TokenKind.LPAREN)) {
      if (_peekIdentifier()) {
        var feature = identifier();           // Media feature.
        while (_maybeEat(TokenKind.COLON)) {
          int startExpr = _peekToken.start;
          var exprs = processExpr();
          if (_maybeEat(TokenKind.RPAREN)) {
            return new MediaExpression(andOperator, feature, exprs,
                _makeSpan(startExpr));
          } else if (messages.options.checked) {
            _warning("Missing parenthesis around media expression",
                _makeSpan(start));
            return null;
          }
        }
      } else if (messages.options.checked) {
        _warning("Missing media feature in media expression", _makeSpan(start));
        return null;
      }
    }
  }

  //  Directive grammar:
  //
  //  import:             '@import' [string | URI] media_list?
  //  media:              '@media' media_query_list '{' ruleset '}'
  //  page:               '@page' [':' IDENT]? '{' declarations '}'
  //  include:            '@include' [string | URI]
  //  stylet:             '@stylet' IDENT '{' ruleset '}'
  //  media_query_list:   IDENT [',' IDENT]
  //  keyframes:          '@-webkit-keyframes ...' (see grammar below).
  //  font_face:          '@font-face' '{' declarations '}'
  //  namespace:          '@namespace name url("xmlns")
  //
  processDirective() {
    int start = _peekToken.start;

    var tokId = _peek();
    // Handle case for @ directive (where there's a whitespace between the @
    // sign and the directive name.  Technically, it's not valid grammar but
    // a number of CSS tests test for whitespace between @ and name.
    if (tokId == TokenKind.AT) {
      Token tok = _next();
      tokId = _peek();
      if (_peekIdentifier()) {
        // Is it a directive?
        var directive = _peekToken.text;
        var directiveLen = directive.length;
        tokId = TokenKind.matchDirectives(directive, 0, directiveLen);
        if (tokId == -1) {
          tokId = TokenKind.matchMarginDirectives(directive, 0, directiveLen);
        }
      } else {
        tokId = -1;
      }

      if (tokId == -1 && messages.options.checked) {
        _warning("Not valid @directive", _makeSpan(start));
        return;
      }
    }

    switch (tokId) {
      case TokenKind.DIRECTIVE_IMPORT:
        _next();

        // @import "uri_string" or @import url("uri_string") are identical; only
        // a url can follow an @import.
        String importStr;
        if (_peekIdentifier()) {
          var func = processFunction(identifier());
          if (func is UriTerm) {
            importStr = func.text;
          }
        } else {
          importStr = processQuotedString(false);
        }

        // Any medias?
        var medias = processMediaQueryList();

        if (importStr == null) {
          _error('missing import string', _peekToken.span);
        }

        return new ImportDirective(importStr.trim(), medias, _makeSpan(start));

      case TokenKind.DIRECTIVE_MEDIA:
        _next();

        // Any medias?
        var media = processMediaQueryList();

        List<TreeNode> rulesets = [];
        if (_maybeEat(TokenKind.LBRACE)) {
          while (!_maybeEat(TokenKind.END_OF_FILE)) {
            RuleSet ruleset = processRuleSet();
            if (ruleset == null) {
              break;
            }
            rulesets.add(ruleset);
          }

          if (!_maybeEat(TokenKind.RBRACE)) {
            _error('expected } after ruleset for @media', _peekToken.span);
          }
        } else {
          _error('expected { after media before ruleset', _peekToken.span);
        }
        return new MediaDirective(media, rulesets, _makeSpan(start));

      case TokenKind.DIRECTIVE_PAGE:
        /*
         * @page S* IDENT? pseudo_page?
         *      S* '{' S*
         *      [ declaration | margin ]?
         *      [ ';' S* [ declaration | margin ]? ]* '}' S*
         *
         * pseudo_page :
         *      ':' [ "left" | "right" | "first" ]
         *
         * margin :
         *      margin_sym S* '{' declaration [ ';' S* declaration? ]* '}' S*
         *
         * margin_sym : @top-left-corner, @top-left, @bottom-left, etc.
         *
         * See http://www.w3.org/TR/css3-page/#CSS21
         */
        _next();

        // Page name
        var name;
        if (_peekIdentifier()) {
          name = identifier();
        }

        // Any pseudo page?
        var pseudoPage;
        if (_maybeEat(TokenKind.COLON)) {
          if (_peekIdentifier()) {
            pseudoPage = identifier();
            // TODO(terry): Normalize pseudoPage to lowercase.
            if (messages.options.checked &&
                !(pseudoPage.name == 'left' ||
                  pseudoPage.name == 'right' ||
                  pseudoPage.name == 'first')) {
              _warning("Pseudo page must be left, top or first",
                  pseudoPage.span);
              return;
            }
          }
        }

        String pseudoName = pseudoPage is Identifier ? pseudoPage.name : '';
        String ident = name is Identifier ? name.name : '';
        return new PageDirective(ident, pseudoName,
            processMarginsDeclarations(), _makeSpan(start));

      case TokenKind.DIRECTIVE_KEYFRAMES:
        /*  Key frames grammar:
         *
         *  @-webkit-keyframes [IDENT|STRING] '{' keyframes-blocks '}';
         *
         *  keyframes-blocks:
         *    [keyframe-selectors '{' declarations '}']* ;
         *
         *  keyframe-selectors:
         *    ['from'|'to'|PERCENTAGE] [',' ['from'|'to'|PERCENTAGE] ]* ;
         */
        _next();

        var name;
        if (_peekIdentifier()) {
          name = identifier();
        }

        _eat(TokenKind.LBRACE);

        KeyFrameDirective kf = new KeyFrameDirective(name, _makeSpan(start));

        do {
          Expressions selectors = new Expressions(_makeSpan(start));

          do {
            var term = processTerm();

            // TODO(terry): Only allow from, to and PERCENTAGE ...

            selectors.add(term);
          } while (_maybeEat(TokenKind.COMMA));

          kf.add(new KeyFrameBlock(selectors, processDeclarations(),
              _makeSpan(start)));

        } while (!_maybeEat(TokenKind.RBRACE));

        return kf;

      case TokenKind.DIRECTIVE_FONTFACE:
        _next();

        List<Declaration> decls = [];

        // TODO(terry): To Be Implemented

        return new FontFaceDirective(decls, _makeSpan(start));

      case TokenKind.DIRECTIVE_INCLUDE:
        _next();
        String filename = processQuotedString(false);
        // Does CSS file exist?
        // TODO(sigmund,terry): this code seemed to be broken and unreachable
        // (there was no fileExist or readAll methods defined anywhere in the
        // original code).
        if (new io.File(path.join(_basePath, filename)).existsSync()) {
          var dir = path.dirname(filename);
          var basePath = path.join(_basePath, dir);
          // Yes, let's parse this file as well.
          var fullFN = path.join(basePath, filename);
          var contents = new io.File(fullFN).readAsStringSync();
          Parser parser = new Parser(
              new File.text(fullFN, contents), contents, 0, basePath);
          StyleSheet stylesheet = parser.parse();
          return new IncludeDirective(filename, stylesheet, _makeSpan(start));
        }

        _error('file doesn\'t exist $filename', _peekToken.span);

        print("WARNING: @include doesn't work for uitest");
        return new IncludeDirective(filename, null, _makeSpan(start));

      case TokenKind.DIRECTIVE_STYLET:
        /* Stylet grammar:
         *
         *  @stylet IDENT '{'
         *    ruleset
         *  '}'
         */
        _next();

        var name;
        if (_peekIdentifier()) {
          name = identifier();
        }

        _eat(TokenKind.LBRACE);

        List<TreeNode> productions = [];

        start = _peekToken.start;
        while (!_maybeEat(TokenKind.END_OF_FILE)) {
          RuleSet ruleset = processRuleSet();
          if (ruleset == null) {
            break;
          }
          productions.add(ruleset);
        }

        _eat(TokenKind.RBRACE);

        return new StyletDirective(name, productions, _makeSpan(start));

      case TokenKind.DIRECTIVE_NAMESPACE:
        /* Namespace grammar:
         *
         * @namespace S* [namespace_prefix S*]? [STRING|URI] S* ';' S*
         * namespace_prefix : IDENT
         *
         */
        _next();

        var prefix;
        if (_peekIdentifier()) {
          prefix = identifier();
        }

        // The namespace URI can be either a quoted string url("uri_string")
        // are identical.
        String namespaceUri;
        if (_peekIdentifier()) {
          var func = processFunction(identifier());
          if (func is UriTerm) {
            namespaceUri = func.text;
          }
        } else {
          if (prefix != null && prefix.name == 'url') {
            var func = processFunction(prefix);
            if (func is UriTerm) {
              // @namespace url("");
              namespaceUri = func.text;
              prefix = null;
            }
          } else {
            namespaceUri = processQuotedString(false);
          }
        }

        return new NamespaceDirective(prefix != null ? prefix.name : '',
            namespaceUri, _makeSpan(start));
    }
  }

  RuleSet processRuleSet() {
    int start = _peekToken.start;

    SelectorGroup selGroup = processSelectorGroup();
    if (selGroup != null) {
      return new RuleSet(selGroup, processDeclarations(), _makeSpan(start));
    }
  }

  DeclarationGroup processDeclarations() {
    int start = _peekToken.start;

    _eat(TokenKind.LBRACE);

    List<Declaration> decls = [];
    List dartStyles = [];             // List of latest styles exposed to Dart.
    do {
      Declaration decl = processDeclaration(dartStyles);
      if (decl != null) {
        if (decl.hasDartStyle) {
          var newDartStyle = decl.dartStyle;

          // Replace or add latest Dart style.
          bool replaced = false;
          for (var i = 0; i < dartStyles.length; i++) {
            var dartStyle = dartStyles[i];
            if (dartStyle.isSame(newDartStyle)) {
              dartStyles[i] = newDartStyle;
              replaced = true;
              break;
            }
          }
          if (!replaced) {
            dartStyles.add(newDartStyle);
          }
        }
        decls.add(decl);
      }
    } while (_maybeEat(TokenKind.SEMICOLON));

    _eat(TokenKind.RBRACE);

    // Fixup declaration to only have dartStyle that are live for this set of
    // declarations.
    for (var decl in decls) {
      if (decl.hasDartStyle && dartStyles.indexOf(decl.dartStyle) < 0) {
        // Dart style not live, ignore these styles in this Declarations.
        decl.dartStyle = null;
      }
    }

    return new DeclarationGroup(decls, _makeSpan(start));
  }

  List<DeclarationGroup> processMarginsDeclarations() {
    List groups = [];

    int start = _peekToken.start;

    _eat(TokenKind.LBRACE);

    List<Declaration> decls = [];
    List dartStyles = [];             // List of latest styles exposed to Dart.

    do {
      switch (_peek()) {
        case TokenKind.MARGIN_DIRECTIVE_TOPLEFTCORNER:
        case TokenKind.MARGIN_DIRECTIVE_TOPLEFT:
        case TokenKind.MARGIN_DIRECTIVE_TOPCENTER:
        case TokenKind.MARGIN_DIRECTIVE_TOPRIGHT:
        case TokenKind.MARGIN_DIRECTIVE_TOPRIGHTCORNER:
        case TokenKind.MARGIN_DIRECTIVE_BOTTOMLEFTCORNER:
        case TokenKind.MARGIN_DIRECTIVE_BOTTOMLEFT:
        case TokenKind.MARGIN_DIRECTIVE_BOTTOMCENTER:
        case TokenKind.MARGIN_DIRECTIVE_BOTTOMRIGHT:
        case TokenKind.MARGIN_DIRECTIVE_BOTTOMRIGHTCORNER:
        case TokenKind.MARGIN_DIRECTIVE_LEFTTOP:
        case TokenKind.MARGIN_DIRECTIVE_LEFTMIDDLE:
        case TokenKind.MARGIN_DIRECTIVE_LEFTBOTTOM:
        case TokenKind.MARGIN_DIRECTIVE_RIGHTTOP:
        case TokenKind.MARGIN_DIRECTIVE_RIGHTMIDDLE:
        case TokenKind.MARGIN_DIRECTIVE_RIGHTBOTTOM:
          // Margin syms processed.
          //   margin :
          //      margin_sym S* '{' declaration [ ';' S* declaration? ]* '}' S*
          //
          //      margin_sym : @top-left-corner, @top-left, @bottom-left, etc.
          var marginSym = _peek();

          _next();

          var declGroup = processDeclarations();
          if (declGroup != null) {
            groups.add(new MarginGroup(marginSym, declGroup.declarations,
                _makeSpan(start)));
          }
          break;
        default:
          Declaration decl = processDeclaration(dartStyles);
          if (decl != null) {
            if (decl.hasDartStyle) {
              var newDartStyle = decl.dartStyle;

              // Replace or add latest Dart style.
              bool replaced = false;
              for (var i = 0; i < dartStyles.length; i++) {
                var dartStyle = dartStyles[i];
                if (dartStyle.isSame(newDartStyle)) {
                  dartStyles[i] = newDartStyle;
                  replaced = true;
                  break;
                }
              }
              if (!replaced) {
                dartStyles.add(newDartStyle);
              }
            }
            decls.add(decl);
          }
          _maybeEat(TokenKind.SEMICOLON);
          break;
      }
    } while (!_maybeEat(TokenKind.RBRACE));

    // Fixup declaration to only have dartStyle that are live for this set of
    // declarations.
    for (var decl in decls) {
      if (decl.hasDartStyle && dartStyles.indexOf(decl.dartStyle) < 0) {
        // Dart style not live, ignore these styles in this Declarations.
        decl.dartStyle = null;
      }
    }

    if (decls.length > 0) {
      groups.add(new DeclarationGroup(decls, _makeSpan(start)));
    }

    return groups;
  }

  SelectorGroup processSelectorGroup() {
    List<Selector> selectors = [];
    int start = _peekToken.start;
    do {
      Selector selector = processSelector();
      if (selector != null) {
        selectors.add(selector);
      }
    } while (_maybeEat(TokenKind.COMMA));

    if (selectors.length > 0) {
      return new SelectorGroup(selectors, _makeSpan(start));
    }
  }

  /* Return list of selectors
   *
   */
  processSelector() {
    List<SimpleSelectorSequence> simpleSequences = [];
    int start = _peekToken.start;
    while (true) {
      // First item is never descendant make sure it's COMBINATOR_NONE.
      var selectorItem = simpleSelectorSequence(simpleSequences.length == 0);
      if (selectorItem != null) {
        simpleSequences.add(selectorItem);
      } else {
        break;
      }
    }

    if (simpleSequences.length > 0) {
      return new Selector(simpleSequences, _makeSpan(start));
    }
  }

  simpleSelectorSequence(bool forceCombinatorNone) {
    int start = _peekToken.start;
    int combinatorType = TokenKind.COMBINATOR_NONE;

    switch (_peek()) {
      case TokenKind.PLUS:
        _eat(TokenKind.PLUS);
        combinatorType = TokenKind.COMBINATOR_PLUS;
        break;
      case TokenKind.GREATER:
        _eat(TokenKind.GREATER);
        combinatorType = TokenKind.COMBINATOR_GREATER;
        break;
      case TokenKind.TILDE:
        _eat(TokenKind.TILDE);
        combinatorType = TokenKind.COMBINATOR_TILDE;
        break;
    }

    // Check if WHITESPACE existed between tokens if so we're descendent.
    if (combinatorType == TokenKind.COMBINATOR_NONE && !forceCombinatorNone) {
      if (this._previousToken != null &&
          this._previousToken.end != this._peekToken.start) {
        combinatorType = TokenKind.COMBINATOR_DESCENDANT;
      }
    }

    var simpleSel = simpleSelector();
    if (simpleSel != null) {
      return new SimpleSelectorSequence(simpleSel, _makeSpan(start),
          combinatorType);
    }
  }

  /**
   * Simple selector grammar:
   *
   *    simple_selector_sequence
   *       : [ type_selector | universal ]
   *         [ HASH | class | attrib | pseudo | negation ]*
   *       | [ HASH | class | attrib | pseudo | negation ]+
   *    type_selector
   *       : [ namespace_prefix ]? element_name
   *    namespace_prefix
   *       : [ IDENT | '*' ]? '|'
   *    element_name
   *       : IDENT
   *    universal
   *       : [ namespace_prefix ]? '*'
   *    class
   *       : '.' IDENT
   */
  simpleSelector() {
    // TODO(terry): Nathan makes a good point parsing of namespace and element
    //              are essentially the same (asterisk or identifier) other
    //              than the error message for element.  Should consolidate the
    //              code.
    // TODO(terry): Need to handle attribute namespace too.
    var first;
    int start = _peekToken.start;
    switch (_peek()) {
      case TokenKind.ASTERISK:
        // Mark as universal namespace.
        var tok = _next();
        first = new Wildcard(_makeSpan(tok.start));
        break;
      case TokenKind.IDENTIFIER:
        first = identifier();
        break;
      default:
        // Expecting simple selector.
        // TODO(terry): Could be a synthesized token like value, etc.
        if (TokenKind.isKindIdentifier(_peek())) {
          first = identifier();
        }
        break;
    }

    if (_maybeEat(TokenKind.NAMESPACE)) {
      var element;
      switch (_peek()) {
        case TokenKind.ASTERISK:
          // Mark as universal element
          var tok = _next();
          element = new Wildcard(_makeSpan(tok.start));
          break;
        case TokenKind.IDENTIFIER:
          element = identifier();
          break;
        default:
          _error('expected element name or universal(*), but found $_peekToken',
              _peekToken.span);
          break;
      }

      return new NamespaceSelector(first,
          new ElementSelector(element, element.span), _makeSpan(start));
    } else if (first != null) {
      return new ElementSelector(first, _makeSpan(start));
    } else {
      // Check for HASH | class | attrib | pseudo | negation
      return simpleSelectorTail();
    }
  }

  bool _anyWhiteSpaceBeforePeekToken(int kind) {
    if (_previousToken != null && _peekToken != null &&
        _previousToken.kind == kind) {
      // If end of previous token isn't same as the start of peek token then
      // there's something between these tokens probably whitespace.
      return _previousToken.end != _peekToken.start;
    }

    return false;
  }

  simpleSelectorTail() {
    // Check for HASH | class | attrib | pseudo | negation
    int start = _peekToken.start;
    switch (_peek()) {
      case TokenKind.HASH:
        _eat(TokenKind.HASH);

        bool hasWhiteSpace = false;
        if (_anyWhiteSpaceBeforePeekToken(TokenKind.HASH)) {
          _warning("Not a valid ID selector expected #id", _makeSpan(start));
          hasWhiteSpace = true;
        }
        var id = identifier();
        if (hasWhiteSpace) {
          // Generate bad selector id (normalized).
          id.name = " ${id.name}";
        }
        return new IdSelector(id, _makeSpan(start));
      case TokenKind.DOT:
        _eat(TokenKind.DOT);

        bool hasWhiteSpace = false;
        if (_anyWhiteSpaceBeforePeekToken(TokenKind.DOT)) {
          _warning("Not a valid class selector expected .className",
              _makeSpan(start));
          hasWhiteSpace = true;
        }
        var id = identifier();
        if (hasWhiteSpace) {
          // Generate bad selector class (normalized).
          id.name = " ${id.name}";
        }
        return new ClassSelector(id, _makeSpan(start));
      case TokenKind.COLON:
        // :pseudo-class ::pseudo-element
        // TODO(terry): '::' should be token.
        _eat(TokenKind.COLON);
        bool pseudoElement = _maybeEat(TokenKind.COLON);
        var name = identifier();
        // TODO(terry): Need to handle specific pseudo class/element name and
        // backward compatible names that are : as well as :: as well as
        // parameters.
        return pseudoElement ?
            new PseudoElementSelector(name, _makeSpan(start)) :
            new PseudoClassSelector(name, _makeSpan(start));
      case TokenKind.LBRACK:
        return processAttribute();
      case TokenKind.DOUBLE:
        _error('name must start with a alpha character, but found a number',
            _peekToken.span);
        _next();
        break;
    }
  }

  //  Attribute grammar:
  //
  //  attributes :
  //    '[' S* IDENT S* [ ATTRIB_MATCHES S* [ IDENT | STRING ] S* ]? ']'
  //
  //  ATTRIB_MATCHES :
  //    [ '=' | INCLUDES | DASHMATCH | PREFIXMATCH | SUFFIXMATCH | SUBSTRMATCH ]
  //
  //  INCLUDES:         '~='
  //
  //  DASHMATCH:        '|='
  //
  //  PREFIXMATCH:      '^='
  //
  //  SUFFIXMATCH:      '$='
  //
  //  SUBSTRMATCH:      '*='
  //
  //
  processAttribute() {
    int start = _peekToken.start;

    if (_maybeEat(TokenKind.LBRACK)) {
      var attrName = identifier();

      int op = TokenKind.NO_MATCH;
      switch (_peek()) {
      case TokenKind.EQUALS:
      case TokenKind.INCLUDES:        // ~=
      case TokenKind.DASH_MATCH:      // |=
      case TokenKind.PREFIX_MATCH:    // ^=
      case TokenKind.SUFFIX_MATCH:    // $=
      case TokenKind.SUBSTRING_MATCH: // *=
        op = _peek();
        _next();
        break;
      }

      var value;
      if (op != TokenKind.NO_MATCH) {
        // Operator hit so we require a value too.
        if (_peekIdentifier()) {
          value = identifier();
        } else {
          value = processQuotedString(false);
        }

        if (value == null) {
          _error('expected attribute value string or ident', _peekToken.span);
        }
      }

      _eat(TokenKind.RBRACK);

      return new AttributeSelector(attrName, op, value, _makeSpan(start));
    }
  }

  //  Declaration grammar:
  //
  //  declaration:  property ':' expr prio?
  //
  //  property:  IDENT
  //  prio:      !important
  //  expr:      (see processExpr)
  //
  processDeclaration(List dartStyles) {
    Declaration decl;

    int start = _peekToken.start;

    // IDENT ':' expr '!important'?
    if (TokenKind.isIdentifier(_peekToken.kind)) {
      var propertyIdent = identifier();

      _eat(TokenKind.COLON);

      Expressions exprs = processExpr();

      var dartComposite = _styleForDart(propertyIdent, exprs, dartStyles);
      decl = new Declaration(propertyIdent, exprs, dartComposite,
          _makeSpan(start));

      // Handle !important (prio)
      decl.important = _maybeEat(TokenKind.IMPORTANT);
    }

    return decl;
  }

  /** List of styles exposed to the Dart UI framework. */
  static const int _fontPartFont= 0;
  static const int _fontPartVariant = 1;
  static const int _fontPartWeight = 2;
  static const int _fontPartSize = 3;
  static const int _fontPartFamily = 4;
  static const int _fontPartStyle = 5;
  static const int _marginPartMargin = 6;
  static const int _marginPartLeft = 7;
  static const int _marginPartTop = 8;
  static const int _marginPartRight = 9;
  static const int _marginPartBottom = 10;
  static const int _lineHeightPart = 11;
  static const int _borderPartBorder = 12;
  static const int _borderPartLeft = 13;
  static const int _borderPartTop = 14;
  static const int _borderPartRight = 15;
  static const int _borderPartBottom = 16;
  static const int _borderPartWidth = 17;
  static const int _borderPartLeftWidth = 18;
  static const int _borderPartTopWidth = 19;
  static const int _borderPartRightWidth = 20;
  static const int _borderPartBottomWidth = 21;
  static const int _heightPart = 22;
  static const int _widthPart = 23;
  static const int _paddingPartPadding = 24;
  static const int _paddingPartLeft = 25;
  static const int _paddingPartTop = 26;
  static const int _paddingPartRight = 27;
  static const int _paddingPartBottom = 28;

  static const Map<String, int> _stylesToDart = const {
    'font':                 _fontPartFont,
    'font-family':          _fontPartFamily,
    'font-size':            _fontPartSize,
    'font-style':           _fontPartStyle,
    'font-variant':         _fontPartVariant,
    'font-weight':          _fontPartWeight,
    'line-height':          _lineHeightPart,
    'margin':               _marginPartMargin,
    'margin-left':          _marginPartLeft,
    'margin-right':         _marginPartRight,
    'margin-top':           _marginPartTop,
    'margin-bottom':        _marginPartBottom,
    'border':               _borderPartBorder,
    'border-left':          _borderPartLeft,
    'border-right':         _borderPartRight,
    'border-top':           _borderPartTop,
    'border-bottom':        _borderPartBottom,
    'border-width':         _borderPartWidth,
    'border-left-width':    _borderPartLeftWidth,
    'border-top-width':     _borderPartTopWidth,
    'border-right-width':   _borderPartRightWidth,
    'border-bottom-width':  _borderPartBottomWidth,
    'height':               _heightPart,
    'width':                _widthPart,
    'padding':              _paddingPartPadding,
    'padding-left':         _paddingPartLeft,
    'padding-top':          _paddingPartTop,
    'padding-right':        _paddingPartRight,
    'padding-bottom':       _paddingPartBottom
  };

  static const Map<String, int> _nameToFontWeight = const {
    'bold' : FontWeight.bold,
    'normal' : FontWeight.normal
  };

  static _findStyle(String styleName) {
    if (_stylesToDart.containsKey(styleName)) {
      return _stylesToDart[styleName];
    }
  }

  _styleForDart(Identifier property, Expressions exprs, List dartStyles) {
    int styleType = _findStyle(property.name.toLowerCase());
    if (styleType != null) {
      return buildDartStyleNode(styleType, exprs, dartStyles);
    }
  }

  FontExpression _mergeFontStyles(FontExpression fontExpr, List dartStyles) {
    // Merge all font styles for this class selector.
    for (var dartStyle in dartStyles) {
      if (dartStyle.isFont) {
        fontExpr = new FontExpression.merge(dartStyle, fontExpr);
      }
    }

    return fontExpr;
  }

  buildDartStyleNode(int styleType, Expressions exprs, List dartStyles) {
    switch (styleType) {
      /*
       * Properties in order:
       *
       *   font-style font-variant font-weight font-size/line-height font-family
       *
       * The font-size and font-family values are required. If other values are
       * missing; a default, if it exist, will be used.
       */
       case _fontPartFont:
         var processor = new ExpressionsProcessor(exprs);
         return _mergeFontStyles(processor.processFont(), dartStyles);
      case _fontPartFamily:
        var processor = new ExpressionsProcessor(exprs);

        try {
          return _mergeFontStyles(processor.processFontFamily(), dartStyles);
        } catch (fontException) {
          _error(fontException, _peekToken.span);
        }
        break;
      case _fontPartSize:
        var processor = new ExpressionsProcessor(exprs);
        return _mergeFontStyles(processor.processFontSize(), dartStyles);
      case _fontPartStyle:
        /* Possible style values:
         *   normal [default]
         *   italic
         *   oblique
         *   inherit
         */
        // TODO(terry): TBD
        break;
      case _fontPartVariant:
        /* Possible variant values:
         *   normal  [default]
         *   small-caps
         *   inherit
         */
        // TODO(terry): TBD
        break;
      case _fontPartWeight:
        /* Possible weight values:
         *   normal [default]
         *   bold
         *   bolder
         *   lighter
         *   100 - 900
         *   inherit
         */
        // TODO(terry): Only 'normal', 'bold', or values of 100-900 supoorted
        //              need to handle bolder, lighter, and inherit.  See
        //              https://github.com/dart-lang/csslib/issues/1
        var expr = exprs.expressions[0];
        if (expr is NumberTerm) {
          var fontExpr = new FontExpression(expr.span,
              weight: expr.value);
          return _mergeFontStyles(fontExpr, dartStyles);
        } else if (expr is LiteralTerm) {
          int weight = _nameToFontWeight[expr.value.toString()];
          if (weight != null) {
            var fontExpr = new FontExpression(expr.span, weight: weight);
            return _mergeFontStyles(fontExpr, dartStyles);
          }
        }
        break;
      case _lineHeightPart:
        num lineHeight;
        if (exprs.expressions.length == 1) {
          var expr = exprs.expressions[0];
          if (expr is UnitTerm) {
            UnitTerm unitTerm = expr;
            // TODO(terry): Need to handle other units and LiteralTerm normal
            //              See https://github.com/dart-lang/csslib/issues/2.
            if (unitTerm.unit == TokenKind.UNIT_LENGTH_PX ||
                   unitTerm.unit == TokenKind.UNIT_LENGTH_PT) {
              var fontExpr = new FontExpression(expr.span,
                  lineHeight: new LineHeight(expr.value, inPixels: true));
              return _mergeFontStyles(fontExpr, dartStyles);
            } else if (messages.options.checked) {
              _warning("Unexpected unit for line-height", expr.span);
            }
          } else if (expr is NumberTerm) {
            var fontExpr = new FontExpression(expr.span,
                lineHeight: new LineHeight(expr.value, inPixels: false));
            return _mergeFontStyles(fontExpr, dartStyles);
          } else if (messages.options.checked) {
            _warning("Unexpected value for line-height", expr.span);
          }
        }
        break;
      case _marginPartMargin:
        return new MarginExpression.boxEdge(exprs.span, processFourNums(exprs));
      case _borderPartBorder:
        for (var expr in exprs.expressions) {
          var v = marginValue(expr);
          if (v != null) {
            final box = new BoxEdge.uniform(v);
            return new BorderExpression.boxEdge(exprs.span, box);
          }
        }
        break;
      case _borderPartWidth:
        var v = marginValue(exprs.expressions[0]);
        if (v != null) {
          final box = new BoxEdge.uniform(v);
          return new BorderExpression.boxEdge(exprs.span, box);
        }
        break;
      case _paddingPartPadding:
        return new PaddingExpression.boxEdge(exprs.span,
            processFourNums(exprs));
      case _marginPartLeft:
      case _marginPartTop:
      case _marginPartRight:
      case _marginPartBottom:
      case _borderPartLeft:
      case _borderPartTop:
      case _borderPartRight:
      case _borderPartBottom:
      case _borderPartLeftWidth:
      case _borderPartTopWidth:
      case _borderPartRightWidth:
      case _borderPartBottomWidth:
      case _heightPart:
      case _widthPart:
      case _paddingPartLeft:
      case _paddingPartTop:
      case _paddingPartRight:
      case _paddingPartBottom:
        if (exprs.expressions.length > 0) {
          return processOneNumber(exprs, styleType);
        }
        break;
      default:
        // Don't handle it.
        return;
    }
  }

  // TODO(terry): Look at handling width of thin, thick, etc. any none numbers
  //              to convert to a number.
  processOneNumber(Expressions exprs, int part) {
    var value = marginValue(exprs.expressions[0]);
    if (value != null) {
      switch (part) {
        case _marginPartLeft:
          return new MarginExpression(exprs.span, left: value);
        case _marginPartTop:
          return new MarginExpression(exprs.span, top: value);
        case _marginPartRight:
          return new MarginExpression(exprs.span, right: value);
        case _marginPartBottom:
          return new MarginExpression(exprs.span, bottom: value);
        case _borderPartLeft:
        case _borderPartLeftWidth:
          return new BorderExpression(exprs.span, left: value);
        case _borderPartTop:
        case _borderPartTopWidth:
          return new BorderExpression(exprs.span, top: value);
        case _borderPartRight:
        case _borderPartRightWidth:
          return new BorderExpression(exprs.span, right: value);
        case _borderPartBottom:
        case _borderPartBottomWidth:
          return new BorderExpression(exprs.span, bottom: value);
        case _heightPart:
          return new HeightExpression(exprs.span, value);
        case _widthPart:
          return new WidthExpression(exprs.span, value);
        case _paddingPartLeft:
          return new PaddingExpression(exprs.span, left: value);
        case _paddingPartTop:
          return new PaddingExpression(exprs.span, top: value);
        case _paddingPartRight:
          return new PaddingExpression(exprs.span, right: value);
        case _paddingPartBottom:
          return new PaddingExpression(exprs.span, bottom: value);
      }
    }
  }

  /**
   * Margins are of the format:
   *
   *   top,right,bottom,left      (4 parameters)
   *   top,right/left, bottom     (3 parameters)
   *   top/bottom,right/left      (2 parameters)
   *   top/right/bottom/left      (1 parameter)
   *
   * The values of the margins can be a unit or unitless or auto.
   */
  processFourNums(Expressions exprs) {
    num top;
    num right;
    num bottom;
    num left;

    int totalExprs = exprs.expressions.length;
    switch (totalExprs) {
      case 1:
        top = marginValue(exprs.expressions[0]);
        right = top;
        bottom = top;
        left = top;
        break;
      case 2:
        top = marginValue(exprs.expressions[0]);
        bottom = top;
        right = marginValue(exprs.expressions[1]);
        left = right;
       break;
      case 3:
        top = marginValue(exprs.expressions[0]);
        right = marginValue(exprs.expressions[1]);
        left = right;
        bottom = marginValue(exprs.expressions[2]);
        break;
      case 4:
        top = marginValue(exprs.expressions[0]);
        right = marginValue(exprs.expressions[1]);
        bottom = marginValue(exprs.expressions[2]);
        left = marginValue(exprs.expressions[3]);
        break;
      default:
        return;
    }

    return new BoxEdge.clockwiseFromTop(top, right, bottom, left);
  }

  // TODO(terry): Need to handle auto.
  marginValue(var exprTerm) {
    if (exprTerm is UnitTerm || exprTerm is NumberTerm) {
      return exprTerm.value;
    }
  }


  //  Expression grammar:
  //
  //  expression:   term [ operator? term]*
  //
  //  operator:     '/' | ','
  //  term:         (see processTerm)
  //
  processExpr() {
    int start = _peekToken.start;
    Expressions expressions = new Expressions(_makeSpan(start));

    bool keepGoing = true;
    var expr;
    while (keepGoing && (expr = processTerm()) != null) {
      var op;

      int opStart = _peekToken.start;

      switch (_peek()) {
      case TokenKind.SLASH:
        op = new OperatorSlash(_makeSpan(opStart));
        break;
      case TokenKind.COMMA:
        op = new OperatorComma(_makeSpan(opStart));
        break;
      }

      if (expr != null) {
        expressions.add(expr);
      } else {
        keepGoing = false;
      }

      if (op != null) {
        expressions.add(op);
        _next();
      }
    }

    return expressions;
  }

  //  Term grammar:
  //
  //  term:
  //    unary_operator?
  //    [ term_value ]
  //    | STRING S* | IDENT S* | URI S* | UNICODERANGE S* | hexcolor
  //
  //  term_value:
  //    NUMBER S* | PERCENTAGE S* | LENGTH S* | EMS S* | EXS S* | ANGLE S* |
  //    TIME S* | FREQ S* | function
  //
  //  NUMBER:       {num}
  //  PERCENTAGE:   {num}%
  //  LENGTH:       {num}['px' | 'cm' | 'mm' | 'in' | 'pt' | 'pc']
  //  EMS:          {num}'em'
  //  EXS:          {num}'ex'
  //  ANGLE:        {num}['deg' | 'rad' | 'grad']
  //  TIME:         {num}['ms' | 's']
  //  FREQ:         {num}['hz' | 'khz']
  //  function:     IDENT '(' expr ')'
  //
  processTerm() {
    int start = _peekToken.start;
    Token t;                          // token for term's value
    var value;                        // value of term (numeric values)

    var unary = "";
    switch (_peek()) {
    case TokenKind.HASH:
      this._eat(TokenKind.HASH);
      if (!_anyWhiteSpaceBeforePeekToken(TokenKind.HASH)) {
        String hexText;
        if (_peekKind(TokenKind.INTEGER)) {
          String hexText1 = _peekToken.text;
          _next();
          if (_peekIdentifier()) {
            hexText = '$hexText1${identifier().name}';
          } else {
            hexText = hexText1;
          }
        } else if (_peekIdentifier()) {
          hexText = identifier().name;
        }
        if (hexText != null) {
          return _parseHex(hexText, _makeSpan(start));
        }
      }

      if (messages.options.checked) {
        _warning("Expected hex number", _makeSpan(start));
      }
      // Construct the bad hex value with a #<space>number.
      return _parseHex(" ${processTerm().text}", _makeSpan(start));
    case TokenKind.INTEGER:
      t = _next();
      value = int.parse("${unary}${t.text}");
      break;
    case TokenKind.DOUBLE:
      t = _next();
      value = double.parse("${unary}${t.text}");
      break;
    case TokenKind.SINGLE_QUOTE:
    case TokenKind.DOUBLE_QUOTE:
      value = processQuotedString(false);
      value = '"${value}"';
      return new LiteralTerm(value, value, _makeSpan(start));
    case TokenKind.LPAREN:
      _next();

      GroupTerm group = new GroupTerm(_makeSpan(start));

      do {
        var term = processTerm();
        if (term != null && term is LiteralTerm) {
          group.add(term);
        }
      } while (!_maybeEat(TokenKind.RPAREN));

      return group;
    case TokenKind.LBRACK:
      _next();

      var term = processTerm();
      if (!(term is NumberTerm)) {
        _error('Expecting a positive number', _makeSpan(start));
      }

      _eat(TokenKind.RBRACK);

      return new ItemTerm(term.value, term.text, _makeSpan(start));
    case TokenKind.IDENTIFIER:
      var nameValue = identifier();   // Snarf up the ident we'll remap, maybe.

      if (_maybeEat(TokenKind.LPAREN)) {
        // FUNCTION
        return processFunction(nameValue);
      } else {
        // TODO(terry): Need to have a list of known identifiers today only
        //              'from' is special.
        if (nameValue.name == 'from') {
          return new LiteralTerm(nameValue, nameValue.name, _makeSpan(start));
        }

        // What kind of identifier is it?
        try {
          // Named color?
          int colorValue = TokenKind.matchColorName(nameValue.name);

          // Yes, process the color as an RGB value.
          String rgbColor = TokenKind.decimalToHex(colorValue, 6);
          return _parseHex(rgbColor, _makeSpan(start));
        } catch (error) {
          if (error is NoColorMatchException) {
            var errMsg = TokenKind.isPredefinedName(error.name) ?
                "Improper use of property value ${error.name}" :
                "Unknown property value ${error.name}";
            _warning(errMsg, _makeSpan(start));
            return new LiteralTerm(nameValue, nameValue.name, _makeSpan(start));
          }
        }
      }
      break;
    }

    var term;
    var unitType = this._peek();

    switch (unitType) {
    case TokenKind.UNIT_EM:
      term = new EmTerm(value, t.text, _makeSpan(start));
      _next();    // Skip the unit
      break;
    case TokenKind.UNIT_EX:
      term = new ExTerm(value, t.text, _makeSpan(start));
      _next();    // Skip the unit
      break;
    case TokenKind.UNIT_LENGTH_PX:
    case TokenKind.UNIT_LENGTH_CM:
    case TokenKind.UNIT_LENGTH_MM:
    case TokenKind.UNIT_LENGTH_IN:
    case TokenKind.UNIT_LENGTH_PT:
    case TokenKind.UNIT_LENGTH_PC:
      term = new LengthTerm(value, t.text, _makeSpan(start), unitType);
      _next();    // Skip the unit
      break;
    case TokenKind.UNIT_ANGLE_DEG:
    case TokenKind.UNIT_ANGLE_RAD:
    case TokenKind.UNIT_ANGLE_GRAD:
    case TokenKind.UNIT_ANGLE_TURN:
      term = new AngleTerm(value, t.text, _makeSpan(start), unitType);
      _next();    // Skip the unit
      break;
    case TokenKind.UNIT_TIME_MS:
    case TokenKind.UNIT_TIME_S:
      term = new TimeTerm(value, t.text, _makeSpan(start), unitType);
      _next();    // Skip the unit
      break;
    case TokenKind.UNIT_FREQ_HZ:
    case TokenKind.UNIT_FREQ_KHZ:
      term = new FreqTerm(value, t.text, _makeSpan(start), unitType);
      _next();    // Skip the unit
      break;
    case TokenKind.PERCENT:
      term = new PercentageTerm(value, t.text, _makeSpan(start));
      _next();    // Skip the %
      break;
    case TokenKind.UNIT_FRACTION:
      term = new FractionTerm(value, t.text, _makeSpan(start));
      _next();     // Skip the unit
      break;
    case TokenKind.UNIT_RESOLUTION_DPI:
    case TokenKind.UNIT_RESOLUTION_DPCM:
    case TokenKind.UNIT_RESOLUTION_DPPX:
      term = new ResolutionTerm(value, t.text, _makeSpan(start), unitType);
      _next();    // Skip the unit
      break;
    case TokenKind.UNIT_CH:
      term = new ChTerm(value, t.text, _makeSpan(start), unitType);
      _next();    // Skip the unit
      break;
    case TokenKind.UNIT_REM:
      term = new RemTerm(value, t.text, _makeSpan(start), unitType);
      _next();    // Skip the unit
      break;
    case TokenKind.UNIT_VIEWPORT_VW:
    case TokenKind.UNIT_VIEWPORT_VH:
    case TokenKind.UNIT_VIEWPORT_VMIN:
    case TokenKind.UNIT_VIEWPORT_VMAX:
      term = new ViewportTerm(value, t.text, _makeSpan(start), unitType);
      _next();    // Skip the unit
      break;
    default:
      if (value != null) {
        term = new NumberTerm(value, t.text, _makeSpan(start));
      }
      break;
    }

    return term;
  }

  processQuotedString([bool urlString = false]) {
    int start = _peekToken.start;

    // URI term sucks up everything inside of quotes(' or ") or between parens
    int stopToken = urlString ? TokenKind.RPAREN : -1;
    switch (_peek()) {
    case TokenKind.SINGLE_QUOTE:
      stopToken = TokenKind.SINGLE_QUOTE;
      start = _peekToken.start + 1;   // Skip the quote might have whitespace.
      _next();    // Skip the SINGLE_QUOTE.
      break;
    case TokenKind.DOUBLE_QUOTE:
      stopToken = TokenKind.DOUBLE_QUOTE;
      start = _peekToken.start + 1;   // Skip the quote might have whitespace.
      _next();    // Skip the DOUBLE_QUOTE.
      break;
    default:
      if (urlString) {
        if (_peek() == TokenKind.LPAREN) {
          _next();    // Skip the LPAREN.
          start = _peekToken.start;
        }
        stopToken = TokenKind.RPAREN;
      } else {
        _error('unexpected string', _makeSpan(start));
      }
      break;
    }

    // Gobble up everything until we hit our stop token.
    int runningStart = _peekToken.start;
    while (_peek() != stopToken && _peek() != TokenKind.END_OF_FILE) {
      var tok = _next();
    }

    // All characters between quotes is the string.
    int end = _peekToken.end;
    var stringValue = (_peekToken.span as FileSpan).file.getText(start, end - 1);

    if (stopToken != TokenKind.RPAREN) {
      _next();    // Skip the SINGLE_QUOTE or DOUBLE_QUOTE;
    }

    return stringValue;
  }

  //  Function grammar:
  //
  //  function:     IDENT '(' expr ')'
  //
  processFunction(Identifier func) {
    int start = _peekToken.start;

    String name = func.name;

    switch (name) {
    case 'url':
      // URI term sucks up everything inside of quotes(' or ") or between parens
      String urlParam = processQuotedString(true);

      // TODO(terry): Better error messge and checking for mismatched quotes.
      if (_peek() == TokenKind.END_OF_FILE) {
        _error("problem parsing URI", _peekToken.span);
      }

      if (_peek() == TokenKind.RPAREN) {
        _next();
      }

      return new UriTerm(urlParam, _makeSpan(start));
    case 'calc':
      // TODO(terry): Implement expression handling...
      break;
    default:
      var expr = processExpr();
      if (!_maybeEat(TokenKind.RPAREN)) {
        _error("problem parsing function expected ), ", _peekToken.span);
      }

      return new FunctionTerm(name, name, expr, _makeSpan(start));
    }

    return null;
  }

  identifier() {
    var tok = _next();

    if (!TokenKind.isIdentifier(tok.kind) &&
        !TokenKind.isKindIdentifier(tok.kind)) {
      if (messages.options.checked) {
        _warning('expected identifier, but found $tok', tok.span);
      }
      return new Identifier("", _makeSpan(tok.start));
    }

    return new Identifier(tok.text, _makeSpan(tok.start));
  }

  // TODO(terry): Move this to base <= 36 and into shared code.
  static int _hexDigit(int c) {
    if(c >= 48/*0*/ && c <= 57/*9*/) {
      return c - 48;
    } else if (c >= 97/*a*/ && c <= 102/*f*/) {
      return c - 87;
    } else if (c >= 65/*A*/ && c <= 70/*F*/) {
      return c - 55;
    } else {
      return -1;
    }
  }

  HexColorTerm _parseHex(String hexText, Span span) {
    int hexValue = 0;

     for (int i = 0; i < hexText.length; i++) {
      var digit = _hexDigit(hexText.codeUnitAt(i));
      if (digit < 0) {
        _warning('Bad hex number', span);
        return new HexColorTerm(new BAD_HEX_VALUE(), hexText, span);
      }
      hexValue = (hexValue << 4) + digit;
    }

    // Make 3 character hex value #RRGGBB => #RGB iff:
    // high/low nibble of RR is the same, high/low nibble of GG is the same and
    // high/low nibble of BB is the same.
    if (hexText.length == 6 &&
        hexText[0] == hexText[1] &&
        hexText[2] == hexText[3] &&
        hexText[4] == hexText[5]) {
      hexText = '${hexText[0]}${hexText[2]}${hexText[4]}';
    } else if (hexText.length == 4 &&
        hexText[0] == hexText[1] &&
        hexText[2] == hexText[3]) {
      hexText = '${hexText[0]}${hexText[2]}';
    } else if (hexText.length == 2 && hexText[0] == hexText[1]) {
      hexText = '${hexText[0]}';
    }
    return new HexColorTerm(hexValue, hexText, span);
  }
}

class ExpressionsProcessor {
  final Expressions _exprs;
  int _index = 0;

  ExpressionsProcessor(this._exprs);

  // TODO(terry): Only handles ##px unit.
  processFontSize() {
    /* font-size[/line-height]
     *
     * Possible size values:
     *   xx-small
     *   small
     *   medium [default]
     *   large
     *   x-large
     *   xx-large
     *   smaller
     *   larger
     *   ##length in px, pt, etc.
     *   ##%, percent of parent elem's font-size
     *   inherit
     */
    LengthTerm size;
    LineHeight lineHt;
    bool nextIsLineHeight = false;
    for (; _index < _exprs.expressions.length; _index++) {
      var expr = _exprs.expressions[_index];
      if (size == null && expr is LengthTerm) {
        // font-size part.
        size = expr;
      } else if (size != null) {
        if (expr is OperatorSlash) {
          // LineHeight could follow?
          nextIsLineHeight = true;
        } else if (nextIsLineHeight && expr is LengthTerm) {
          assert(expr.unit == TokenKind.UNIT_LENGTH_PX);
          lineHt = new LineHeight(expr.value, inPixels: true);
          nextIsLineHeight = false;
          _index++;
          break;
        } else {
          break;
        }
      } else {
        break;
      }
    }

    return new FontExpression(_exprs.span, size: size, lineHeight: lineHt);
  }

  processFontFamily() {
    final List<String> family = <String>[];

    /* Possible family values:
     * font-family: arial, Times new roman ,Lucida Sans Unicode,Courier;
     * font-family: "Times New Roman", arial, Lucida Sans Unicode, Courier;
     */
    bool moreFamilies = false;

    for (; _index < _exprs.expressions.length; _index++) {
      Expression expr = _exprs.expressions[_index];
      if (expr is LiteralTerm) {
        if (family.length == 0 || moreFamilies) {
          // It's font-family now.
          family.add(expr.toString());
          moreFamilies = false;
        } else if (messages.options.checked) {
          messages.warning('Only font-family can be a list', _exprs.span);
        }
      } else if (expr is OperatorComma && family.length > 0) {
        moreFamilies = true;
      } else {
        break;
      }
    }

    return new FontExpression(_exprs.span, family: family);
  }

  processFont() {
    var family;

    // Process all parts of the font expression.
    FontExpression fontSize;
    FontExpression fontFamily;
    for (; _index < _exprs.expressions.length; _index++) {
      var expr = _exprs.expressions[_index];
      // Order is font-size font-family
      if (fontSize == null) {
        fontSize = processFontSize();
      }
      if (fontFamily == null) {
        fontFamily = processFontFamily();
      }
      //TODO(terry): Handle font-weight, font-style, and font-variant. See
      //               https://github.com/dart-lang/csslib/issues/3
      //               https://github.com/dart-lang/csslib/issues/4
      //               https://github.com/dart-lang/csslib/issues/5
    }

    return new FontExpression(_exprs.span,
        size: fontSize.font.size,
        lineHeight: fontSize.font.lineHeight,
        family: fontFamily.font.family);
  }
}
