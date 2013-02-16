// Copyright (c) 2012, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library selector_test;

import 'package:unittest/unittest.dart';
import 'testing.dart';
import 'package:csslib/parser.dart';
import 'package:csslib/visitor.dart';

// Pretty printer for CSS.
var emitSelector = new CssPrinter();

void testSelectorSuccesses() {
  var cssErrors = [];
  var selectorAst = selector('#div .foo', errors: cssErrors);
  expect(cssErrors.isEmpty, true);
  expect('#div .foo', (emitSelector..visitTree(selectorAst)).toString());

  // Valid selectors for class names.
  cssErrors = [];
  selectorAst = selector('.foo', errors: cssErrors);
  expect(cssErrors.isEmpty, true);
  expect('.foo', (emitSelector..visitTree(selectorAst)).toString());

  cssErrors = [];
  selectorAst = selector('.foobar .xyzzy', errors: cssErrors);
  expect(cssErrors.isEmpty, true);
  expect('.foobar .xyzzy', (emitSelector..visitTree(selectorAst)).toString());

  cssErrors = [];
  selectorAst = selector('.foobar .a-story .xyzzy', errors: cssErrors);
  expect(cssErrors.isEmpty, true);
  expect('.foobar .a-story .xyzzy',
      (emitSelector..visitTree(selectorAst)).toString());

  cssErrors = [];
  selectorAst = selector('.foobar .xyzzy .a-story .b-story', errors: cssErrors);
  expect(cssErrors.isEmpty, true);
  expect('.foobar .xyzzy .a-story .b-story',
      (emitSelector..visitTree(selectorAst)).toString());

  // Valid selectors for element IDs.
  cssErrors = [];
  selectorAst = selector('#id1', errors: cssErrors);
  expect(cssErrors.isEmpty, true);
  expect('#id1', (emitSelector..visitTree(selectorAst)).toString());

  cssErrors = [];
  selectorAst = selector('#id-number-3', errors: cssErrors);
  expect(cssErrors.isEmpty, true);
  expect('#id-number-3', (emitSelector..visitTree(selectorAst)).toString());

  cssErrors = [];
  selectorAst = selector('#_privateId', errors: cssErrors);
  expect(cssErrors.isEmpty, true);
  expect('#_privateId', (emitSelector..visitTree(selectorAst)).toString());
}

// TODO(terry): Move this failure case to a failure_test.dart when the analyzer
//              and validator exit then they'll be a bunch more checks.
void testSelectorFailures() {
  // Test for invalid class name (can't start with number).
  var cssErrors = [];
  var selectorAst = selector('.foobar .1a-story .xyzzy', errors: cssErrors);
  expect(cssErrors.isEmpty, false);
  expect(cssErrors[0].toString(), r'''
SEVERE :1:9: name must start with a alpha character, but found a number
.foobar .1a-story .xyzzy
        ^^''');
}

main() {
  test('Valid Selectors', testSelectorSuccesses);
  test('Invalid Selectors', testSelectorFailures);
}
