// Original FDMwerk V7 screenshot compositor. Uses real app captures, never fabricated UI.
// Apple device assets stay private and must be licensed by the publisher separately.
import fs from 'node:fs/promises';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
import {createHash} from 'node:crypto';
import sharp from 'sharp';
import {Torus,Pyramid,Cone,Amphora,Cog,Cuboid,ToyBrick,Blocks,RockingChair,Lamp} from 'lucide';

const project=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..');
const font=path.join(project,'scripts/store-media-assets/Manrope-Variable.ttf');
process.env.FONTCONFIG_FILE ||= path.join(project,'scripts/store-media-assets/fonts.conf');
const W=2560,H=1600;
export const brand={ink:'#1A1033',violet:'#583BFF',lavender:'#D7D0FF',coral:'#FF6C63',white:'#FFFFFF',ivory:'#F8F6F3',muted:'#686171'};
const escape=value=>String(value).replaceAll('&','&amp;').replaceAll('<','&lt;').replaceAll('>','&gt;').replaceAll('"','&quot;');
const digest=buffer=>createHash('sha256').update(buffer).digest('hex');
// Existing manifest theme IDs stay valid, with a consistently light art direction.
const themes={violet:{background:'#FCFCFB',foreground:brand.ink,secondary:brand.muted},plum:{background:'#FAF9FC',foreground:brand.ink,secondary:brand.muted},lavender:{background:'#FAFAFD',foreground:brand.ink,secondary:brand.muted},ivory:{background:brand.ivory,foreground:brand.ink,secondary:brand.muted}};
const doodles=[
 {name:'Torus',nodes:Torus,x:52,y:400,size:150,angle:-15},
 {name:'Cuboid',nodes:Cuboid,x:2220,y:300,size:185,angle:16},
 {name:'Pyramid',nodes:Pyramid,x:120,y:1240,size:160,angle:12},
 {name:'Cone',nodes:Cone,x:2310,y:1180,size:150,angle:-18},
 {name:'Amphora',nodes:Amphora,x:2100,y:1410,size:100,angle:14},
 {name:'Cog',nodes:Cog,x:365,y:155,size:100,angle:-10},
 {name:'ToyBrick',nodes:ToyBrick,x:80,y:760,size:120,angle:-12},
 {name:'RockingChair',nodes:RockingChair,x:2340,y:750,size:125,angle:10},
 {name:'Lamp',nodes:Lamp,x:325,y:1390,size:95,angle:-9},
 {name:'Blocks',nodes:Blocks,x:2050,y:100,size:115,angle:12}
];
export const suggestedSlides=[
 {id:'01-models',theme:'violet',de:{headline:'Kostenloser 3D Viewer',subtitle:'Der klare CAD Viewer für deinen Mac.'},en:{headline:'Free 3D Viewer',subtitle:'The clear CAD viewer for your Mac.'}},
 {id:'02-explore',theme:'ivory',de:{headline:'Öffnen. Drehen.\nVerstehen.',subtitle:'3D-Modelle entdecken. Ganz in deinem Tempo.'},en:{headline:'Open. Rotate.\nUnderstand.',subtitle:'Explore your 3D models at your own pace.'}},
 {id:'03-measure',theme:'lavender',de:{headline:'Maße, die\nKlarheit schaffen.',subtitle:'Außenmaße, Details und Abstände im Blick.'},en:{headline:'Measurements\nthat make sense.',subtitle:'See dimensions, details and distances clearly.'}},
 {id:'04-organize',theme:'plum',de:{headline:'Alles im Blick.',subtitle:'Mehrere Modelle. Eine aufgeräumte Ansicht.'},en:{headline:'Every detail in view.',subtitle:'Multiple models. One clear workspace.'}},
 {id:'05-appearance',theme:'violet',de:{headline:'Dein Blick.\nDeine Perspektive.',subtitle:'Vertraute Ansichten. Farben, die bleiben.'},en:{headline:'Your view.\nYour perspective.',subtitle:'Familiar views. Original colors.'}}
];

async function textImage(text,{size=96,color=brand.white,width=2240,weight=300,align='centre'}={}){
 const buffer=await sharp({text:{text:`<span foreground="${color}" weight="${weight}">${escape(text)}</span>`,font:`Manrope ${size}`,fontfile:font,width,align,rgba:true,dpi:72,spacing:4}}).png().toBuffer();
 const info=await sharp(buffer).metadata();return {buffer,width:info.width,height:info.height};
}
function background(theme,generic=false){
 // Decorative model doodles use unmodified Lucide paths, not invented icon drawings.
 const headerPositions=[{x:420,y:35,size:90},{x:2250,y:65,size:105},{x:690,y:25,size:85},{x:2400,y:210,size:85},{x:1870,y:35,size:100},{x:100,y:215,size:90},{x:560,y:245,size:62},{x:1990,y:240,size:70},{x:1580,y:35,size:70},{x:1110,y:28,size:65}];
 const visibleDoodles=generic?doodles.map((d,i)=>({...d,...headerPositions[i]})):doodles;
 const drawings=visibleDoodles.map(({nodes,x,y,size,angle})=>`<g transform="translate(${x} ${y}) rotate(${angle} ${size/2} ${size/2})" opacity="${generic?.42:.21}"><svg width="${size}" height="${size}" viewBox="0 0 24 24" fill="none" stroke="#ABA7B1" stroke-width="1" stroke-linecap="round" stroke-linejoin="round">${nodes.map(([tag,attrs])=>`<${tag} ${Object.entries(attrs).map(([key,value])=>`${key}="${escape(value)}"`).join(' ')}/>`).join('')}</svg></g>`).join('');
 return Buffer.from(`<svg xmlns="http://www.w3.org/2000/svg" width="${W}" height="${H}"><rect width="${W}" height="${H}" fill="${theme.background}"/>${drawings}<rect x="1238" y="478" width="84" height="4" rx="2" fill="${brand.violet}" opacity=".32"/></svg>`);
}
function slideTheme(slide){const theme=themes[slide.theme||'ivory'];if(!theme)throw Error('Unknown brand theme.');return theme}
function slideCopy(copy){return {headline:copy.headline.replaceAll('\\n','\n'),subtitle:copy.subtitle||''}}
async function brandOverlays(manifest,copy,slide,theme){
 const headline=await textImage(slideCopy(copy).headline,{size:slide.headlineSize||104,color:theme.foreground,width:2240,weight:600});
 if(headline.height>320)throw Error('Headline exceeds the reserved title area; shorten it or reduce headlineSize.');
 const top=Number.isFinite(manifest.headerCenterY)?Math.round(manifest.headerCenterY-headline.height/2):slide.headlineTop??(slideCopy(copy).headline.includes('\n')?126:190);
 const overlays=[{input:headline.buffer,left:Math.round((W-headline.width)/2),top}];
 if(copy.subtitle){const subtitle=await textImage(copy.subtitle,{size:28,color:theme.secondary,width:2100,weight:400});if(subtitle.height>80)throw Error('Subtitle exceeds reserved space.');overlays.push({input:subtitle.buffer,left:Math.round((W-subtitle.width)/2),top:top+headline.height+24})}
 if(manifest.publisherLogo){
  const logo=await sharp(await fs.readFile(manifest.publisherLogo)).resize(manifest.publisherLogoWidth||125,manifest.publisherLogoHeight||46,{fit:'contain',background:theme.background}).flatten({background:theme.background}).png().toBuffer();
  overlays.push({input:logo,left:96,top:Number.isFinite(manifest.headerCenterY)?Math.round(manifest.headerCenterY-(manifest.publisherLogoHeight||46)/2):60});
 }else{
  const mark=await sharp(await fs.readFile(manifest.formMark||path.join(project,'Resources/Web/app-mark.png'))).resize(40,46,{fit:'contain'}).png().toBuffer();
  overlays.push({input:mark,left:96,top:60});
 }
 const credit=copy.credit||slide.credit||manifest.modelCredit;
 if(credit){const caption=await textImage(credit,{size:19,color:manifest.footerColor||theme.secondary,width:2300,weight:400});if(caption.height>50)throw Error('Credit caption is too long.');overlays.push({input:caption.buffer,left:Math.round((W-caption.width)/2),top:manifest.creditTop??(manifest.footerBandHeight?Math.round(H-manifest.footerBandHeight+(manifest.footerBandHeight-caption.height)/2):1552)})}
 return {overlays,headline,credit};
}
async function verifyDevice(device){
 if(!device?.file||!device?.screen||device.publisherLicenseAccepted!==true)throw Error('An original licensed Apple bezel and publisherLicenseAccepted=true are required. No simulated Apple hardware is generated.');
 const input=await fs.readFile(device.file),meta=await sharp(input).metadata(),screen=device.screen;
 for(const key of ['left','top','width','height'])if(!Number.isFinite(screen[key])||screen[key]<0)throw Error('Invalid device screen rectangle.');
 if(screen.width<=0||screen.height<=0||screen.left+screen.width>meta.width||screen.top+screen.height>meta.height)throw Error('Screen rectangle exceeds the original bezel.');
 return {input,meta,screen};
}
// Prepare only licensed brand typography and the real captures. This deliberately
// does not read/use/mount Apple artwork or create final framed screenshots.
export async function prepareStoreMedia(manifest){
 const output=path.resolve(manifest.outputDirectory||path.join(project,'build/store-media-2026-11-08'));
 const directory=path.join(output,'prepared');await fs.mkdir(directory,{recursive:true});
 const result={status:'Layout studies only: light V7 typography, Lucide doodles and real app captures; no hardware used. Official Apple bezel approval/composition pending.',doodles:{source:'lucide 1.70.0',license:'ISC',names:doodles.map(d=>d.name)},images:[],fontSHA256:digest(await fs.readFile(font))};
 for(const [index,slide]of(manifest.slides||[]).entries())for(const locale of manifest.languages||['de','en']){
  const copy=slide[locale];if(!copy?.capture||!copy?.headline)throw Error(`Missing actual ${locale} capture/headline.`);
  const input=await fs.readFile(copy.capture),meta=await sharp(input).metadata(),crop=copy.cropTopPixels??manifest.captureTopCropPixels??0;
  if(meta.width<1000||meta.height<600||!Number.isInteger(crop)||crop<0||crop>64)throw Error('Invalid source capture or reserved top crop.');
  const folder=path.join(directory,locale);await fs.mkdir(folder,{recursive:true});const id=slide.id||String(index+1);
  const captureOutput=path.join(folder,id+'-actual-capture.png');
  await sharp(input).extract({left:0,top:crop,width:meta.width,height:meta.height-crop}).removeAlpha().png().toFile(captureOutput);
  const theme=slideTheme(slide),{overlays,headline}=await brandOverlays(manifest,copy,slide,theme);
  await fs.writeFile(path.join(folder,id+'-headline.png'),headline.buffer);
  await sharp(background(theme)).removeAlpha().png().toFile(path.join(folder,id+'-background.png'));
  // A study uses the actual capture directly, never simulated or unlicensed hardware.
  const studyCapture=await sharp(captureOutput).resize(2240,1112,{fit:'contain',background:theme.background}).png().toBuffer();
  overlays.push({input:studyCapture,left:160,top:408});
  const study=path.join(folder,id+'-layout-study.png');
  await sharp(background(theme)).composite(overlays).flatten({background:theme.background}).removeAlpha().png().toFile(study);
  result.images.push({locale,id,source:path.basename(copy.capture),inputFormat:meta.format,sourceSHA256:digest(input),preparedCapture:path.relative(output,captureOutput),layoutStudy:path.relative(output,study),hardware:'none; layout study only',cropTopPixels:crop,width:meta.width,height:meta.height-crop,headline:slideCopy(copy).headline,headlineWidth:headline.width,headlineHeight:headline.height});
 }
 await fs.writeFile(path.join(directory,'PREPARED.json'),JSON.stringify(result,null,2)+'\n');
 const thumbs=[];for(const image of result.images){const input=await sharp(path.join(output,image.preparedCapture)).resize(640,400,{fit:'contain',background:'#fafafa'}).png().toBuffer();thumbs.push({input,left:thumbs.length%2*640,top:Math.floor(thumbs.length/2)*400})}
 if(thumbs.length)await sharp({create:{width:1280,height:Math.ceil(thumbs.length/2)*400,channels:3,background:'#fafafa'}}).composite(thumbs).removeAlpha().png().toFile(path.join(directory,'CAPTURE_CONTACT_SHEET.png'));
 const studyThumbs=[];for(const image of result.images){const data=await sharp(path.join(output,image.layoutStudy)).resize(640,400).png().toBuffer();studyThumbs.push({input:data,left:studyThumbs.length%2*640,top:Math.floor(studyThumbs.length/2)*400})}
 if(studyThumbs.length)await sharp({create:{width:1280,height:Math.ceil(studyThumbs.length/2)*400,channels:3,background:'#fff'}}).composite(studyThumbs).png().toFile(path.join(directory,'LAYOUT_STUDY_CONTACT_SHEET.png'));
 console.log(`Prepared ${result.images.length} actual captures and light layout studies. No Apple bezel read, mounted, used or license accepted.`);return result;
}

export async function composeStoreMedia(manifest){
 const output=path.resolve(manifest.outputDirectory||path.join(project,'build/store-media-2026-11-08'));
 const generic=manifest.presentation==='generic-screen';
 const device=generic?null:await verifyDevice(manifest.device),languages=manifest.languages||['de','en'];
 if(!languages.length||languages.some(locale=>!['de','en'].includes(locale)))throw Error('Use separate German and/or English media sets.');
 await fs.mkdir(output,{recursive:true});
 const sourceReport={createdAt:new Date().toISOString(),artDirection:'Light surface, large Manrope headlines and subtle Lucide model doodles',doodles:{source:'lucide 1.70.0',license:'ISC',names:doodles.map(d=>d.name)},canvas:{width:W,height:H},brandGuide:'FDMwerk Brandbook V7 / AKTUELL.txt',font:{family:'Manrope',license:'SIL OFL 1.1',notice:'scripts/store-media-assets/OFL-Manrope.txt'},device:generic?{type:'Generic rounded display border',appleAssetUsed:false,details:'No notch, logo, chassis or claim of Apple hardware. Lower canvas clipping intentional.'}:{source:manifest.device.sourceURL||null,asset:path.basename(manifest.device.file),sha256:digest(device.input),screen:device.screen,alterations:'Proportional resizing only. No crop, added shadow, tilt or repaint.'},images:[]};
 for(const [index,slide]of(manifest.slides||[]).entries())for(const locale of languages){
  const copy=slide[locale];if(!copy?.capture||!copy?.headline)throw Error(`Missing actual ${locale} capture/headline for ${slide.id||index}.`);
  const capture=await fs.readFile(copy.capture),captureMeta=await sharp(capture).metadata();
  if(captureMeta.width<1000||captureMeta.height<600)throw Error('Use a real app capture of at least 1000×600 pixels.');
  const theme=slideTheme(slide),{overlays,headline,credit}=await brandOverlays(manifest,copy,slide,theme);
  const insideCredit=generic&&manifest.creditInsideScreen&&credit?overlays.pop():null;
  if(generic){
   const cropTop=copy.cropTopPixels??manifest.captureTopCropPixels??0;
   if(!Number.isInteger(cropTop)||cropTop<0||cropTop>64)throw Error('Invalid reserved top crop.');
   const box={left:100,top:340,width:2360,height:1416,...manifest.genericScreen};
   const border=18,radius=38,innerRadius=radius-border,innerWidth=box.width-border*2;
   let app=sharp(capture).extract({left:0,top:cropTop,width:captureMeta.width,height:captureMeta.height-cropTop}).resize({width:innerWidth});
   let appBuffer=await app.png().toBuffer();const appMeta=await sharp(appBuffer).metadata();
   const innerMask=Buffer.from(`<svg width="${appMeta.width}" height="${appMeta.height}"><rect width="${appMeta.width}" height="${appMeta.height}" rx="${innerRadius}" fill="white"/></svg>`);
   appBuffer=await sharp(appBuffer).composite([{input:innerMask,blend:'dest-in'}]).png().toBuffer();
   const fullHeight=Math.max(box.height,appMeta.height+border*2);
   const mask=Buffer.from(`<svg width="${box.width}" height="${fullHeight}"><rect width="${box.width}" height="${fullHeight}" rx="${radius}" fill="white"/></svg>`);
   const screen=await sharp({create:{width:box.width,height:fullHeight,channels:4,background:'#151515'}}).composite([{input:appBuffer,left:border,top:border}]).png().toBuffer();
   let framed=await sharp(screen).composite([{input:mask,blend:'dest-in'}]).png().toBuffer();
   const footerHeight=manifest.footerBandHeight||0;
   const visibleHeight=Math.min(fullHeight,H-footerHeight-box.top);
   framed=await sharp(framed).extract({left:0,top:0,width:box.width,height:visibleHeight}).png().toBuffer();
   overlays.push({input:framed,left:box.left,top:box.top});
  }else{
  // Place the full original bezel proportionally. The device itself is never cropped.
  const box={left:96,top:408,width:2368,height:1120,...manifest.device.placement};
  const scale=Math.min(box.width/device.meta.width,box.height/device.meta.height);
  const dw=Math.round(device.meta.width*scale),dh=Math.round(device.meta.height*scale),dx=Math.round(box.left+(box.width-dw)/2),dy=Math.round(box.top+(box.height-dh)/2);
  if(dx<0||dy<0||dx+dw>W||dy+dh>H)throw Error('Device placement crops the original bezel.');
  const s=device.screen,sx=Math.round(s.left*scale),sy=Math.round(s.top*scale),sw=Math.round(s.width*scale),sh=Math.round(s.height*scale);
  // Preserve all captured UI. Letterboxing is allowed; distortion/cropping is not.
  const cropTop=copy.cropTopPixels??manifest.captureTopCropPixels??0;
  if(!Number.isInteger(cropTop)||cropTop<0||cropTop>64||cropTop>=captureMeta.height)throw Error('Only the reserved top 0–64 OS/titlebar pixels may be cropped.');
  const screenshot=await sharp(capture).extract({left:0,top:cropTop,width:captureMeta.width,height:captureMeta.height-cropTop}).resize(sw,sh,{fit:'contain',background:'#fafafa'}).png().toBuffer();
  const bezel=await sharp(device.input).resize(dw,dh,{fit:'fill'}).png().toBuffer();
  overlays.push({input:screenshot,left:dx+sx,top:dy+sy},{input:bezel,left:dx,top:dy});
  }
  if(insideCredit)overlays.push(insideCredit);
  const directory=path.join(output,locale);await fs.mkdir(directory,{recursive:true});const filename=`${String(index+1).padStart(2,'0')}-${slide.id||'form'}-${locale}.png`,target=path.join(directory,filename);
  await sharp(background(theme,generic)).composite(overlays).flatten({background:theme.background}).removeAlpha().png().toFile(target);
  const rendered=await sharp(target).metadata();if(rendered.width!==W||rendered.height!==H||rendered.hasAlpha)throw Error('App Store output dimensions/alpha mismatch.');
  sourceReport.images.push({locale,file:path.relative(output,target),capture:path.basename(copy.capture),captureSHA256:digest(capture),cropTopPixels:copy.cropTopPixels??manifest.captureTopCropPixels??0,headline:copy.headline,theme:slide.theme||'violet',credit:credit||null});
 }
 await fs.writeFile(path.join(output,'MEDIA_PROVENANCE.json'),JSON.stringify(sourceReport,null,2)+'\n');
 // A contact sheet is a private review artifact, not a screenshot for upload.
 const thumbs=[];for(const image of sourceReport.images){const data=await sharp(path.join(output,image.file)).resize(640,400).png().toBuffer();thumbs.push({input:data,left:(thumbs.length%2)*640,top:Math.floor(thumbs.length/2)*400})}
 if(thumbs.length)await sharp({create:{width:1280,height:Math.ceil(thumbs.length/2)*400,channels:3,background:'#ffffff'}}).composite(thumbs).png().toFile(path.join(output,'CONTACT_SHEET.png'));
 console.log(`Prepared ${sourceReport.images.length} private 2560×1600 screenshots in ${output}`);
 return sourceReport;
}
if(process.argv[1]&&path.resolve(process.argv[1])===fileURLToPath(import.meta.url)){
 if(process.argv[2]==='--example'){console.log(JSON.stringify({outputDirectory:'build/store-media-2026-11-08',languages:['de','en'],device:{file:'PRIVATE_PATH_TO_ORIGINAL_APPLE_BEZEL.png',sourceURL:'https://developer.apple.com/design/resources/',publisherLicenseAccepted:false,screen:{left:0,top:0,width:0,height:0}},slides:suggestedSlides.map(slide=>({...slide,de:{...slide.de,capture:`build/store-media-2026-11-08/raw/${slide.id}-de.png`},en:{...slide.en,capture:`build/store-media-2026-11-08/raw/${slide.id}-en.png`}}))},null,2))}
 else if(process.argv[2]==='--prepare'){if(!process.argv[3])throw Error('Provide the private manifest path.');await prepareStoreMedia(JSON.parse(await fs.readFile(process.argv[3],'utf8')))}
 else{if(!process.argv[2])throw Error('Usage: node scripts/store-media.mjs private-manifest.json (or --prepare manifest / --example).');await composeStoreMedia(JSON.parse(await fs.readFile(process.argv[2],'utf8')))}
}
