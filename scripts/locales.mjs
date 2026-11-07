import fs from 'node:fs';
const files=fs.readdirSync('Resources/Web/locales').filter(name=>name.endsWith('.json')).sort();
fs.writeFileSync('locale-catalogs.js',files.map((file,i)=>`import l${i} from './Resources/Web/locales/${file}' with {type:'json'};`).join('\n')+'\nexport default {'+files.map((file,i)=>`${JSON.stringify(file.slice(0,-5))}:l${i}`).join(',')+'};\n');
