// Packages only committed project files plus the verified corresponding-source archives.
// Run after committing the release tree; untracked customer files and credentials stay out.
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
import {execFileSync} from 'node:child_process';

const tarEnvironment={...process.env,COPYFILE_DISABLE:'1'};
const isMetadata=name=>name.startsWith('._')||name==='.DS_Store'||name==='__MACOSX';

// Only called on our newly created staging directory. Do not follow symlinks,
// touch the working tree, or change metadata on the original source archives.
export function removeStagingMetadata(directory){
 for(const entry of fs.readdirSync(directory,{withFileTypes:true})){
  const target=path.join(directory,entry.name);
  if(isMetadata(entry.name))fs.rmSync(target,{recursive:entry.isDirectory(),force:true});
  else if(entry.isDirectory())removeStagingMetadata(target);
 }
}

export function createSourceTar({parentDirectory,name,output}){
 const stage=path.join(parentDirectory,name);
 if(path.basename(name)!==name||!fs.statSync(stage).isDirectory())throw Error('Invalid source staging directory.');
 removeStagingMetadata(stage);
 // COPYFILE_DISABLE suppresses macOS AppleDouble; the explicit flags also
 // suppress extended-attribute and ACL PAX records. GNU/BSD tar support these.
 execFileSync('tar',['--no-xattrs','--no-acls','-czf',output,'-C',parentDirectory,name],{env:tarEnvironment});
 const entries=execFileSync('tar',['-tzf',output],{env:tarEnvironment,encoding:'utf8'}).split('\n').filter(Boolean);
 if(entries.some(entry=>entry.split('/').some(isMetadata)))throw Error('Source archive contains unwanted AppleDouble/Finder metadata.');
 if(entries.some(entry=>entry.split('/').some(part=>/\.(?:app|xcarchive)$/i.test(part))||/\.(?:dmg|pkg)$/i.test(entry)))throw Error('Source archive contains an application/distribution binary.');
 return entries;
}

export async function packageSource(){
 const archiveEnv={...process.env,COPYFILE_DISABLE:'1'};
const sourceManifest=JSON.parse(fs.readFileSync('vendor-source-manifest.json','utf8'));
const version=JSON.parse(fs.readFileSync('package.json','utf8')).version;
 if(!/^\d+\.\d+\.\d+(?:[-.][0-9A-Za-z.-]+)?$/.test(version))throw Error('Invalid source-package version.');
 const commit=execFileSync('git',['rev-parse','HEAD'],{encoding:'utf8'}).trim();
 const dirty=execFileSync('git',['status','--porcelain','--untracked-files=no'],{encoding:'utf8'}).trim();
 if(dirty)throw Error('Commit the final source changes before creating the source package.');
 // Dirty-tree rejection precedes downloads or vendor-source writes.
 await import('./vendor-sources.mjs');
 const temp=fs.mkdtempSync(path.join(os.tmpdir(),'form-source-package-'));
 const name=`Form-${version}-source`,stage=path.join(temp,name),trackedTar=path.join(temp,'tracked-source.tar');
 try{
  fs.mkdirSync(stage);
  execFileSync('git',['archive','--format=tar','-o',trackedTar,'HEAD']);
  execFileSync('tar',['--no-xattrs','--no-acls','-xf',trackedTar,'-C',stage],{env:tarEnvironment});
  const sourceDir=path.join(stage,'vendor-source');fs.mkdirSync(sourceDir,{recursive:true});for(const item of sourceManifest.archives)fs.copyFileSync(path.join('vendor-source',item.file),path.join(sourceDir,item.file));fs.copyFileSync('vendor-source-manifest.json',path.join(sourceDir,'manifest.json'));
  fs.writeFileSync(path.join(stage,'SOURCE_RELEASE.json'),JSON.stringify({application:'Form',version,commit,originalApplicationLicense:'MIT',correspondingSourceManifest:'vendor-source/manifest.json'},null,2)+'\n');
  const prepared=path.join(temp,`${name}.tar.gz`);
  createSourceTar({parentDirectory:temp,name,output:prepared});
  fs.mkdirSync('distribution',{recursive:true});
  const output=path.resolve('distribution',`${name}.tar.gz`);
  fs.renameSync(prepared,output);
  console.log(output);
  return output;
 }finally{fs.rmSync(temp,{recursive:true,force:true})}
}

if(process.argv[1]&&path.resolve(process.argv[1])===fileURLToPath(import.meta.url))await packageSource();
