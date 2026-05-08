'use strict';
/**
 * Smoke test for dispatch.js after auth was narrowed to git-credential-only.
 */

const { test } = require('node:test');
const assert = require('node:assert/strict');

const dispatch = require('./dispatch.js');

test('dispatch.js loads without throwing', () => {
  assert.ok(dispatch);
});
