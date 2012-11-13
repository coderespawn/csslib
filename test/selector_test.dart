// Copyright (c) 2012, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library selector_test;

import 'package:unittest/unittest.dart';
import 'package:unittest/vm_config.dart';
import 'testing.dart';
import 'package:csslib/parser.dart';

void testSelectorSuccesses() {
  var cssErrors = [];
  var selectorAst = selector('#div .foo', errors: cssErrors);
  expect(cssErrors.isEmpty, true);
  expect('#div .foo', selectorAst.toString());

  // Valid selectors for class names.
  cssErrors = [];
  selectorAst = selector('.foo', errors: cssErrors);
  expect(cssErrors.isEmpty, true);
  expect('.foo', selectorAst.toString());

  cssErrors = [];
  selectorAst = selector('.foobar .xyzzy', errors: cssErrors);
  expect(cssErrors.isEmpty, true);
  expect('.foobar .xyzzy', selectorAst.toString());

  cssErrors = [];
  selectorAst = selector('.foobar .a-story .xyzzy', errors: cssErrors);
  expect(cssErrors.isEmpty, true);
  expect('.foobar .a-story .xyzzy', selectorAst.toString());

  cssErrors = [];
  selectorAst = selector('.foobar .xyzzy .a-story .b-story', errors: cssErrors);
  expect(cssErrors.isEmpty, true);
  expect('.foobar .xyzzy .a-story .b-story', selectorAst.toString());

  // Valid selectors for element IDs.
  cssErrors = [];
  selectorAst = selector('#id1', errors: cssErrors);
  expect(cssErrors.isEmpty, true);
  expect('#id1', selectorAst.toString());

  cssErrors = [];
  selectorAst = selector('#id-number-3', errors: cssErrors);
  expect(cssErrors.isEmpty, true);
  expect('#id-number-3', selectorAst.toString());

  cssErrors = [];
  selectorAst = selector('#_privateId', errors: cssErrors);
  expect(cssErrors.isEmpty, true);
  expect('#_privateId', selectorAst.toString());
}

// TODO(terry): Move this failure case to a failure_test.dart when the analyzer
//              and validator exit then they'll be a bunch more checks.
void testSelectorFailures() {
  // Test for invalid class name (can't start with number).
  var cssErrors = [];
  var selectorAst = selector('.foobar .1a-story .xyzzy', errors: cssErrors);
  expect(cssErrors.isEmpty, false);
  expect(cssErrors[0].toString(), r'''
SEVERE <#SourceFile .foobar .1a-story .xyzzy> @ line 1 (column 8:10)
.foobar .1a-story .xyzzy
        ^^ name must start with a alpha character, but found a number
''');
}

main() {
  useVmConfiguration();
  useMockMessages();

  test('Valid Selectors', testSelectorSuccesses);
  test('Invalid Selectors', testSelectorFailures);
}
