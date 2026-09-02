# Regenerates build/build.lua from src/ in luacompact's output format. Run: python build/bundle.py
import json, os, glob
root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
cfg = json.load(open(os.path.join(root, 'luacompact.json')))
def rd(p): return open(os.path.join(root, p), encoding='utf-8').read()
head = rd('build/build.lua').split('luacompactModules["', 1)[0]
out = [head]
for f in sorted(glob.glob(os.path.join(root, 'src', '**', '*.lua'), recursive=True)):
    rel = os.path.relpath(f, root).replace(os.sep, '/')
    if rel == cfg['main']: continue
    body = '\n'.join(('\t' + l if l else l) for l in rd(rel).split('\n'))
    out.append(f'luacompactModules["{rel}"] = function()\n{body}\nend\n\n')
out.append(rd(cfg['main']))
open(os.path.join(root, 'build/build.lua'), 'w', encoding='utf-8', newline='\n').write(''.join(out))
print('built build/build.lua')
