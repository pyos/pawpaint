#!/usr/bin/env coffee
cs = require '/usr/lib/node_modules/coffee-script'
fs = require 'fs'

code  = ''
path  = process.argv[2] + "/" + process.argv[3]
sfile = process.argv[3].replace('js', 'coffee')
stdin = process.openStdin()
stdin.on 'data', (buf) -> code += buf.toString() if buf
stdin.on 'end', ->
  try
    c = cs.compile(code, {header: false, sourceFiles: [sfile], sourceMap: true})
    fs.writeFile(path,          c.js + "\n//# sourceMappingURL=" + process.argv[3] + ".map\n")
    fs.writeFile(path + ".map", c.v3SourceMap + "\n")
  catch err
    process.stderr.write((err.stack or "" + err) + "\n")
    process.exit(1)
