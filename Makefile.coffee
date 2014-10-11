#!/usr/bin/env coffee
cs = require '/usr/lib/node_modules/coffee-script'
fs = require 'fs'

code  = ''
stdin = process.openStdin()
stdin.on 'data', (buf) -> code += buf.toString() if buf
stdin.on 'end', ->
  try
    c = cs.compile(code, header: false, sourceMap: true)
    fs.writeSync(4, c.js + "\n")
    fs.writeSync(5, c.v3SourceMap + "\n")
  catch err
    process.stderr.write((err.stack or "" + err) + "\n")
    process.exit(1)
