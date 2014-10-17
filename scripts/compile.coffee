#!/usr/bin/env coffee
cs = require '/usr/lib/node_modules/coffee-script'
fs = require 'fs'

code  = ''
tpath = process.argv[2]
tfile = tpath.split('/').pop()
sfile = tfile.replace('js', 'coffee')
stdin = process.openStdin()
stdin.on 'data', (buf) -> code += buf.toString() if buf
stdin.on 'end', ->
  try
    c = cs.compile(code, {header: false, sourceFiles: [sfile], sourceMap: true})
    fs.writeFile(tpath,          c.js + "\n//# sourceMappingURL=" + tfile + ".map\n")
    fs.writeFile(tpath + ".map", c.v3SourceMap + "\n")
  catch err
    process.stderr.write((err.stack or "" + err) + "\n")
    process.exit(1)
