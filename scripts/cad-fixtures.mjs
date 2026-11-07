// These upstream fixtures are extracted locally for testing, not shipped as app demo content.
import fs from 'node:fs';import path from 'node:path';import {execFileSync} from 'node:child_process';import './vendor-sources.mjs';
const destination=process.argv[2]||'.tmp/cad-fixtures';fs.mkdirSync(destination,{recursive:true});const archive='vendor-source/occt-import-js-c2148e5.tar.gz',prefix='occt-import-js-c2148e54b456b571238d35cac037d304053d64b2/test/testfiles/';
for(const [file,source]of [['sample.stp','cube-10x10mm/Cube 10x10.stp'],['sample.igs','cube-10x10mm/Cube 10x10.igs'],['sample.brep','cax-if-brep/as1_pe_203.brep']])fs.writeFileSync(path.join(destination,file),execFileSync('tar',['-xOf',archive,prefix+source],{maxBuffer:20*1024*1024}));
console.log('Prepared pinned upstream CAD test fixtures in '+destination);
