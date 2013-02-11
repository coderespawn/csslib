// Copyright (c) 2013, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library visitor_test;

import 'dart:utf';
import 'package:unittest/unittest.dart';
import 'package:csslib/parser.dart';
import 'package:csslib/visitor.dart';
import 'testing.dart';


// Pretty printer for CSS.
var emitCss = new CssPrinter();
String prettyPrint(StyleSheet ss) =>
    (emitCss..visitTree(ss, pretty: true)).toString();

class ClassVisitor extends Visitor {
  final List expectedClasses;
  final Set<String> foundClasses = new Set();

  ClassVisitor(this.expectedClasses);

  void visitClassSelector(ClassSelector node) {
    foundClasses.add(node.name);
  }

  bool get matches {
    bool match = true;
    foundClasses.forEach((value) {
      match = match && expectedClasses.contains(value);
    });
    expectedClasses.forEach((value) {
      match = match && foundClasses.contains(value);
    });

    return match;
  }
}

void testClassVisitors() {
  var cssErrors = [];

  var in1 = '.foobar { }';

  var s = parseCss(in1, errors: cssErrors);

  var clsVisits = new ClassVisitor(['foobar'])..visitTree(s);
  expect(clsVisits.matches, true);

  cssErrors = [];
  in1= '''
      .foobar1 { }
      .xyzzy .foo #my-div { color: red; }
      div.hello { font: arial; }
    ''';

  s = parseCss(in1, errors: cssErrors);
  clsVisits =
      new ClassVisitor(['foobar1', 'xyzzy', 'foo', 'hello'])..visitTree(s);
  expect(clsVisits.matches, true);

  expect(prettyPrint(s), r'''
.foobar1 {
}
.xyzzy .foo #my-div {
  color: #ff0000;
}
div.hello {
  font: arial;
}''');
}

class PolyfillEmitter extends CssPrinter {
  final String _prefix;

  PolyfillEmitter(this._prefix);

  void visitClassSelector(ClassSelector node) {
    emit('.${_prefix}_${node.name}');
  }
}

String polyfillPrint(String prefix, StyleSheet ss) =>
  (new PolyfillEmitter(prefix)..visitTree(ss, pretty: true)).toString();

void testPolyFill() {
  var cssErrors = [];

  final input = r'''
.foobar { }
div.xyzzy { }
#foo .foo .bar .foobar { }
''';

  final generated = r'''
.myComponent_foobar {
}
div.myComponent_xyzzy {
}
#foo .myComponent_foo .myComponent_bar .myComponent_foobar {
}''';

  var s = parseCss(input, errors: cssErrors);

  final emitted = polyfillPrint('myComponent', s);
  expect(emitted, generated);
}

main() {
  test('Class Visitors', testClassVisitors);
  test('Polyfill', testPolyFill);
}
