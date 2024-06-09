#!/usr/bin/env node

const version = "1.0.0"

import init from './cli/init.js'
import add from './cli/add.js'
import generate from './cli/generate.js'


const main = async () => {
  const [command, ...inputs] = process.argv.slice(2)
  
  switch (command) {
    case "init":
      return init()
    case "add":
      await add(...inputs)
      return generate()
    case "generate":
      return generate()
    case '--version':
    case '-v':
      return console.info(version)
    default:
      if (!command) {
        console.error(`
  Here are the available commands:

    elm-inertia init .......... create a new project
    elm-inertia add <page> .......... add a new page
    elm-inertia generate ... regenerate src/Page.elm
`)
      } else {
        console.error(`
  Unrecognized command "${command}".

  Here are the available commands:

    elm-inertia init .......... create a new project
    elm-inertia add <page> .......... add a new page
    elm-inertia generate ... regenerate src/Page.elm
`)
      }
  }
}

main().catch(console.error)