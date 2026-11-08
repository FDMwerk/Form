import assert from 'node:assert/strict';
import {createViewerHarness} from '../scripts/viewer-test-harness.mjs';
const h=createViewerHarness();
// No mobile marker: the existing desktop grid stays unchanged during zoom.
await h.load('samples/Montageblock.stl');
const original=h.read('grid'),originalCount=original.geometry.attributes.position.count;
h.evaluate('camera.zoom=3;updateMobileGrid()');
assert.equal(h.read('grid'),original);
assert.equal(h.read('grid.geometry.attributes.position.count'),originalCount);
// Test the actual production spacing function over six orders of magnitude.
for(const scale of [.0001,.001,.01,.1,.3,1,10,100]){
 const step=h.read(`mobileGridStep(${scale})`),pixels=step/scale;
 assert.ok(pixels>=24-1e-8&&pixels<=60+1e-8,`readable spacing ${step} at ${scale}`);
 const fraction=step/10**Math.floor(Math.log10(step));assert.ok([1,2,5,10].some(n=>Math.abs(n-fraction)<1e-8));
}
assert.equal(h.read('mobileGridStep(.2,5)'),5,'hysteresis avoids grid flicker during small pinch');
h.evaluate('document.documentElement.dataset.formMobile="true";camera.zoom=1;updateMobileGrid()');
assert.ok(h.read('mobileGridSpacing')>0);
assert.notEqual(h.read('grid'),original);
const mobile=h.read('grid');
assert.ok(mobile.geometry.attributes.position.count<=644,'grid complexity bounded regardless of model size');
const weights=[...mobile.geometry.attributes.gridWeight.array];assert.ok(weights.includes(1.5499999523162842)&&weights.includes(.800000011920929),'major fifth lines and minor lines distinguished');
h.evaluate('updateMobileGrid()');assert.equal(h.read('grid'),mobile,'stationary view does not allocate grid per frame');
const spacing=h.read('mobileGridSpacing');h.evaluate('camera.zoom*=20;updateMobileGrid()');
assert.ok(h.read('mobileGridSpacing')<spacing,'zoom in selects finer millimetre spacing');
assert.ok(h.read('grid.geometry.attributes.position.count')<=644);
h.click('#grid');assert.equal(h.read('grid.visible'),false);
h.evaluate('camera.zoom/=100;updateMobileGrid()');assert.equal(h.read('grid.visible'),false,'zoom rebuild preserves hidden grid');
h.click('[data-background-preset="dark"]');
assert.ok(h.read('grid.material.uniforms.gridOpacity.value')<=.28,'background appearance remains subtle');
assert.match(h.read('grid.material.fragmentShader'),/smoothstep/,'radial fade retained');
h.evaluate('adoptCamera(viewportCameras.setProjection("perspective"));camera.zoom=1;camera.position.copy(controls.target).add(new T.Vector3(100,-100,100));updateMobileGrid()');
const perspectiveStep=h.read('mobileGridSpacing');
h.evaluate('camera.position.sub(controls.target).multiplyScalar(10).add(controls.target);updateMobileGrid()');
assert.ok(h.read('mobileGridSpacing')>perspectiveStep,'perspective dolly adjusts grid spacing too');
console.log('Mobile grid passed: actual production nice steps, zoom/hysteresis, bounded geometry, major/minor, dark background, hidden state and desktop unchanged.');
