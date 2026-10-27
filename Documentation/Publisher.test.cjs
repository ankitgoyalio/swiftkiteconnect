// Offline validation of the guide's examples; never loads scripts or submits forms.
const { readFileSync } = require('node:fs');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const { test } = require('node:test');
const guide = () => readFileSync(`${__dirname}/Publisher.md`, 'utf8');
const block = (language, index = 0) => [...guide().matchAll(new RegExp('```' + language + '\\n([\\s\\S]*?)```', 'g'))][index][1];

test('offsite example prepares a form basket without submitting or loading remote code', () => {
  const html = block('html');
  assert.match(html, /method="post"/);
  assert.match(html, /action="https:\/\/example.invalid\/connect\/basket"/);
  assert.match(html, /name="api_key"/);
  assert.match(html, /name="data"/);
  const data = { value: '' };
  vm.runInNewContext(html.match(/<script>([\s\S]*?)<\/script>/)[1], {
    document: { getElementById(id) { assert.equal(id, 'basket-data'); return data; } },
  });
  assert.deepEqual(JSON.parse(data.value), [{
    exchange: 'NSE', tradingsymbol: 'INFY', transaction_type: 'BUY',
    quantity: 1, order_type: 'LIMIT', product: 'CNC', price: 100,
    variety: 'regular', readonly: false, tag: 'demo23',
  }]);
  assert.equal(new URLSearchParams({ data: data.value }).get('data'), data.value);
});

test('dynamic example waits for plugin readiness and prepares a user-clicked basket', () => {
  let ready;
  let entry;
  let finished;
  let selector;
  class KiteConnect {
    static ready(callback) { ready = callback; }
    constructor(key) { assert.equal(key, 'YOUR_PUBLIC_API_KEY'); }
    add(value) { entry = value; }
    finished(callback) { finished = callback; }
    link(value) { selector = value; }
  }
  vm.runInNewContext(block('javascript', 1), { KiteConnect });
  assert.equal(entry, undefined);
  ready();
  assert.deepEqual(JSON.parse(JSON.stringify(entry)), {
    exchange: 'NSE', tradingsymbol: 'INFY', quantity: 1,
    transaction_type: 'BUY', order_type: 'LIMIT', price: 100,
  });
  assert.equal(selector, '#review-basket');
  assert.equal(typeof finished, 'function');
});

test('callback example accepts only an exact return URL with unique required fields', () => {
  const context = { URL };
  vm.runInNewContext(block('javascript'), context);
  const parse = context.parsePublisherReturn;
  const expected = 'https://app.example/kite-return';
  const success = parse(`${expected}?request_token=fixture&status=success&extra=ignored`, expected);
  assert.equal(success.requestToken, 'fixture');
  assert.equal(success.status, 'success');
  for (const url of [
    'https://evil.example/kite-return?request_token=x&status=success',
    `${expected}/extra?request_token=x&status=success`,
    'http://app.example/kite-return?request_token=x&status=success',
    'https://app.example:8443/kite-return?request_token=x&status=success',
    `${expected}?status=success`,
    `${expected}?request_token=x`,
    `${expected}?request_token=x&request_token=y&status=success`,
    `${expected}?request_token=x&status=success&status=error`,
  ]) assert.equal(parse(url, expected), null);
  assert.equal(parse(`${expected}?request_token=x&status=future`, expected).status, 'future');
});
