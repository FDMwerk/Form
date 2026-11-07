// Illustrative engineering assumptions, not manufacturer or slicer presets.
// Values are starting points in mm/s and mm³/s. User-entered values take priority.
export const materialProfiles=Object.freeze(Object.fromEntries(Object.entries({
  pla:['PLA',60,10],petg:['PETG',50,8],abs:['ABS',55,8],asa:['ASA',55,8],tpu:['TPU',25,3],pa:['PA',45,5],pc:['PC',40,6]
}).map(([key,[name,nominalSpeed,volumetricFlow]])=>[key,Object.freeze({name,nominalSpeed,volumetricFlow})])));

/** Heuristic FFF range, NOT a sliced toolpath or guaranteed bound.
 * Perimeters ≈ projected vertical area × wall count × extrusion width.
 * Caps ≈ projected horizontal area × solid-layer count × layer height.
 * Clamp shell to mesh volume; fill the remaining volume by the infill fraction.
 * Extrusion time = deposited volume / min(speed × width × height, flow limit).
 * Add heuristic short-move/travel overhead and 2s per layer. Display −35%/+50%.
 * Supports, brims, purge, heat-up, tool changes, bed adhesion, acceleration limits,
 * exact polygon offsets, infill paths and model-specific cooling are not simulated.
 */
export function estimatePrint(metrics,options={}) {
  const invalid=reason=>({valid:false,reason,seconds:null,minSeconds:null,maxSeconds:null,rangeSeconds:null,depositedMM3:null,shellMM3:null,infillMM3:null,effectiveFlowMM3s:null,warnings:[reason]});
  if(!metrics?.watertight||!Number.isFinite(metrics.volumeMM3)||metrics.volumeMM3<=0)return invalid('closed-volume-required');
  const material=String(options.material||'pla').toLowerCase(),profile=materialProfiles[material];
  if(!profile)return invalid('unknown-material');
  const values={layerHeight:.2,infillPercent:20,wallCount:2,nozzle:.4,topBottomLayers:4,nominalSpeed:profile.nominalSpeed,volumetricFlow:profile.volumetricFlow,...options};
  for(const key of ['layerHeight','infillPercent','wallCount','nozzle','topBottomLayers','nominalSpeed','volumetricFlow'])if(typeof values[key]!=='number'||!Number.isFinite(values[key]))return invalid('invalid-input');
  const {layerHeight,infillPercent,wallCount,nozzle,topBottomLayers,nominalSpeed,volumetricFlow}=values;
  if(layerHeight<=0||nozzle<=0||layerHeight>nozzle||nozzle>5||layerHeight<.01||infillPercent<0||infillPercent>100||wallCount<0||wallCount>100||!Number.isInteger(wallCount)||topBottomLayers<0||topBottomLayers>100||!Number.isInteger(topBottomLayers)||nominalSpeed<=0||volumetricFlow<=0)return invalid('invalid-input');
  const height=metrics.zHeightMM??metrics.zHeight;
  if(![metrics.surfaceMM2,metrics.verticalAreaMM2,metrics.horizontalAreaMM2,height].every(value=>typeof value==='number'&&Number.isFinite(value)&&value>=0)||height<=0)return invalid('invalid-metrics');
  const extrusionWidth=nozzle*1.1;
  const shellMM3=Math.min(metrics.volumeMM3,metrics.verticalAreaMM2*wallCount*extrusionWidth+metrics.horizontalAreaMM2*topBottomLayers*layerHeight);
  const infillMM3=Math.max(0,metrics.volumeMM3-shellMM3)*infillPercent/100,depositedMM3=shellMM3+infillMM3;
  if(depositedMM3<=0)return invalid('no-deposition');
  const effectiveFlowMM3s=Math.min(nominalSpeed*extrusionWidth*layerHeight,volumetricFlow);
  const layerCount=Math.ceil(height/layerHeight),characteristicLength=Math.sqrt(metrics.volumeMM3/height);
  // Small footprints generally entail proportionally more short moves.
  const motionOverhead=1.2+Math.min(.6,8/Math.max(characteristicLength,1));
  const seconds=depositedMM3/effectiveFlowMM3s*motionOverhead+layerCount*2;
  const minSeconds=seconds*.65,maxSeconds=seconds*1.5;
  const warnings=['heuristic-not-slicer','supports-and-startup-excluded','range-not-guaranteed',...(metrics.warnings||[])];
  return {valid:true,material,seconds,minSeconds,maxSeconds,rangeSeconds:[minSeconds,maxSeconds],depositedMM3,shellMM3,infillMM3,effectiveFlowMM3s,extrusionWidthMM:extrusionWidth,layerCount,warnings};
}
