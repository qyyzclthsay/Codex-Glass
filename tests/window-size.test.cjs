const test = require('node:test');
const assert = require('node:assert/strict');
const {cornerBounds, mainSize} = require('../src/core/window-size.cjs');
const {sanitize} = require('../src/core/storage.cjs');
test('all corners preserve the opposite anchor while shrinking', () => {
  const origin = {x:100,y:100,width:500,height:600}, area = {x:0,y:0,width:1920,height:1080};
  for (const corner of ['nw','ne','sw','se']) {
    const left = corner.includes('w'), top = corner.includes('n');
    const result = cornerBounds(origin,corner,left?100:-100,top?100:-100,area);
    assert.deepEqual(result,{x:left?200:100,y:top?200:100,width:400,height:500});
  }
});
test('minimum dimensions and display edges constrain resizing on a negative-coordinate monitor', () => {
  const origin = {x:-1500,y:80,width:500,height:600}, area = {x:-1920,y:0,width:1920,height:1080};
  assert.deepEqual(cornerBounds(origin,'nw',5000,5000,area),{x:-1320,y:320,width:320,height:360});
  assert.deepEqual(cornerBounds(origin,'nw',-5000,-5000,area),{x:-1900,y:0,width:900,height:680});
  assert.deepEqual(cornerBounds(origin,'se',5000,5000,area),{x:-1500,y:80,width:900,height:1000});
});
test('saved dimensions reject malformed values and clamp out-of-range settings', () => {
  assert.equal(mainSize({width:NaN,height:500}),null);
  assert.equal(sanitize({}).mainSize,null);
  assert.deepEqual(sanitize({mainSize:{width:1,height:9000}}).mainSize,{width:320,height:1400});
  assert.deepEqual(sanitize({mainSize:{width:350,height:480}}).mainSize,{width:350,height:480});
});
