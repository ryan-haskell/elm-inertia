import { rmSync, access, mkdir, existsSync, lstatSync, writeFileSync, readFileSync, mkdirSync, readdirSync, writeFile, utimesSync, statSync } from 'fs'
import { sep, join, basename } from 'path'



// Determines if a file or folder exists
let exists = async (filepath) => {
  try {
    return new Promise((resolve, reject) => {
      access(filepath, (err) => {
        if (err) { resolve(false) } else { resolve(true) }
      })
    })
  } catch (e) {
    return false
  }
}

let createFile = async ({ name, content }) => {
  let pieces = name.split('/')
  let folderPieces = pieces.slice(0, -1)
  let containingFolder = folderPieces.join('/')

  await createFolder({ name: containingFolder })
  await new Promise((resolve, reject) => {
    writeFile(
      join(process.cwd(), ...pieces),
      content, { encoding: 'utf-8' },
      (err) => {
        if (err) {
          reject(err)
        } else {
          resolve(true)
        }
      }
    )
  })
}

let createFolder = async ({ name }) => {
  return new Promise((resolve, reject) => {
    mkdir(
      join(process.cwd(), ...name.split('/')),
      { recursive: true },
      (err, path) => {
        if (err) {
          reject(err)
        } else {
          resolve(path)
        }
      })
  })
}

// Read all the files in the current folder, recursively
let listElmFilepathsInFolder = (filepath) => {
  let folderExists = existsSync(filepath)

  if (folderExists) {
    let fullFilepaths = walk(filepath)
      // Exclude temporary files saved by code editors, such as 'Foo.elm~'.
      .filter(str => str.endsWith('.elm'))
    let relativeFilepaths = fullFilepaths.map(str => str.slice(filepath.length + 1, -'.elm'.length))

    return relativeFilepaths
  } else {
    return []
  }
}

var walk = function (dir) {
  var results = []
  var list = readdirSync(dir)
  list.forEach(function (file) {
    file = dir + '/' + file
    var stat = statSync(file)
    if (stat && stat.isDirectory()) {
      /* Recurse into a subdirectory */
      results = results.concat(walk(file))
    } else {
      /* Is a file */
      results.push(file)
    }
  })
  return results
}


// Copy the contents of one folder into another
let copyPasteFolder = async ({ source, destination }) => {
  // Make sure destination folder exists first!
  await new Promise((resolve, reject) => {
    mkdir(destination, { recursive: true }, (err, path) => {
      if (err) {
        reject(err)
      } else {
        resolve(path)
      }
    })
  })
  copyFolderRecursiveSync(source, destination)
}

let copyPasteFile = async ({ source, destination }) => {

  // Ensure folder exists before pasting file
  let destinationFolder = destination.split(sep).slice(0, -1).join(sep)
  await new Promise((resolve, reject) => {
    mkdir(destinationFolder, { recursive: true }, (err, path) => {
      if (err) {
        reject(err)
      } else {
        resolve(path)
      }
    })
  })

  return copyFileSync(source, destination)
}

function copyFileSync(source, target) {

  var targetFile = target

  // If target is a directory, a new file with the same name will be created
  if (existsSync(target)) {
    if (lstatSync(target).isDirectory()) {
      targetFile = join(target, basename(source))
    }
  }

  writeFileSync(targetFile, readFileSync(source))
}

function copyFolderRecursiveSync(source, target) {
  var files = []

  // Check if folder needs to be created or integrated
  var targetFolder = join(target, basename(source))
  if (!existsSync(targetFolder)) {
    mkdirSync(targetFolder)
  }

  // Copy
  if (lstatSync(source).isDirectory()) {
    files = readdirSync(source)
    files.forEach(function (file) {
      var curSource = join(source, file)
      if (lstatSync(curSource).isDirectory()) {
        copyFolderRecursiveSync(curSource, targetFolder)
      } else {
        copyFileSync(curSource, targetFolder)
      }
    })
  }
}

async function attemptToGetSourceDirectory () {
  // 1. Attempt to read "elm.json" file in current folder
  let elmJsonFilepath = join(process.cwd(), 'elm.json')
  let elmJsonContents = undefined
  try {
    elmJsonContents = readFileSync(elmJsonFilepath, { encoding: 'utf-8' })
  } catch (_) {
    console.warn(`‼️ Could not find "elm.json" file in the current directory.`)
    return undefined
  }

  // 2. Attempt to parse JSON
  let firstSourceDirectory = undefined
  try {
    let elmJson = JSON.parse(elmJsonContents)
    if (elmJson['source-directories'].length === 0) {
      console.warn(`‼️ Could not find any source directories in your "elm.json" file.`)
      return undefined
    }
    firstSourceDirectory = elmJson['source-directories'][0]
  } catch (_) {
    console.warn(`‼️ Could not parse JSON from the "elm.json" file.`)
    return undefined
  }

  return firstSourceDirectory
}

export const Files = {
  createFile,
  createFolder,
  exists,
  listElmFilepathsInFolder,
  copyPasteFolder,
  copyPasteFile,
  attemptToGetSourceDirectory
}