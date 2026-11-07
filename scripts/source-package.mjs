// Packages only committed project files plus the verified corresponding-source archives.
// Run after committing the release tree; untracked customer files and credentials stay out.
import fs from 'node:fs';import os from 'node:os';import path from 'node:path';import {execFileSync} from 'node:child_process';
import './vendor-sources.mjs';
const version=JSON.parse(fs.readFileSync('package.json')).version;
const commit=execFileSync('git',['rev-parse','HEAD'],{encoding:'utf8'}).trim();
const dirty=execFileSync('git',['status','--porcelain','--untracked-files=no'],{encoding:'utf8'}).trim();if(dirty)throw Error('Commit the final source changes before creating the source package.');
const temp=fs.mkdtempSync(path.join(os.tmpdir(),'form-source-package-')),name=`Form-${version}-source`,stage=path.join(temp,name);fs.mkdirSync(stage);const tar=path.join(temp,'tracked-source.tar');
try{execFileSync('git',['archive','--format=tar','-o',tar,'HEAD']);execFileSync('tar',['-xf',tar,'-C',stage]);fs.cpSync('vendor-source',path.join(stage,'third-party-source'),{recursive:true});fs.writeFileSync(path.join(stage,'SOURCE_RELEASE.json'),JSON.stringify({application:'Form',version,commit,originalApplicationLicense:'MIT',correspondingSourceManifest:'third-party-source/manifest.json'},null,2));fs.mkdirSync('distribution',{recursive:true});const output=path.resolve('distribution',`Form-${version}-source.tar.gz`);execFileSync('tar',['-czf',output,'-C',temp,name]);console.log(output)}finally{fs.rmSync(temp,{recursive:true,force:true})}
