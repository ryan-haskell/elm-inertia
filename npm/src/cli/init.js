
import prompts from 'prompts'
import { Files } from './_files.js'
import path from 'path'
import url from 'url'

let __dirname = path.dirname(url.fileURLToPath(import.meta.url))

export default async () => {
  let createdProject = await beginInitPrompt()

  if (createdProject) {
    console.info('')
    console.info('  New project created!')
    console.info('')
  } else {
    console.info('')
    console.info('  No files were changed.')
    console.info('')
  }
}

const beginInitPrompt = async () => {
  console.info('')
  let response = await askQuestions()

  let isOkay = false
  let plan = undefined
  if (response.preset === 'laravel') {
    plan = ({
      rootFolder: [],
      elmRootFolder: [ 'resources', 'elm' ],
    })
  } else if (response.preset === 'rails') {
    plan = ({
      rootFolder: [],
      elmRootFolder: [ 'app', 'elm' ],
    })
  } else {
    plan = await buildCustomPlan()
  }

  if (plan) {
    isOkay = await confirmPlanIsOkayWithUser(plan)
    if (isOkay) {
      await generateNewProject(plan)
      return true
    }
  }

  return false
}

const buildCustomPlan = async () => {
  const response = await prompts([
    {
      type: 'text',
      name: 'rootFolder',
      message: 'Where is the project root?',
      initial: '.'
    },
    {
      type: 'text',
      name: 'elmRootFolder',
      message: 'Which folder should contain the Elm files?',
      initial: '.'
    }
  ])

  const fromStringToFolders = str =>
      (str === '' || str === '.')
        ? []
        : str.split(path.sep).flatMap(x => x.split('/'))

  return {
    rootFolder: fromStringToFolders(response.rootFolder),
    elmRootFolder: fromStringToFolders(response.elmRootFolder)
  }
}

const askQuestions = async () => {
  const response = await prompts(
    [{
      type: 'select',
      name: 'preset',
      message: 'What kind of backend do you have?',
      choices: [
        { title: 'Laravel', value: 'laravel' },
        { title: 'Rails', value: 'rails' },
        { title: 'Custom', value: 'custom' }
      ]
    }]
  )
  return response
}

const dim = (str) => "\x1b[2m" + str + "\x1b[0m"
const yellow = (str) => "\x1b[33m" + str + "\x1b[0m"
const magenta = (str) => "\x1b[35m" + str + "\x1b[0m"
const cyan = (str) => "\x1b[36m" + str + "\x1b[0m"

const confirmPlanIsOkayWithUser = async (plan) => {
  console.info('')
  console.info(`· Creating a new project at ${magenta(process.cwd())}:`)
  console.info(`   - Create ${cyan('elm.json')} at ${dim('.............')} ${yellow(plan.rootFolder.length === 0 ? './elm.json' : './' + [...plan.rootFolder, 'elm.json'].join('/'))}`)
  console.info(`   - Create ${cyan('vite.config.js')} at ${dim('.......')} ${yellow(plan.rootFolder.length === 0 ? './vite.config.js' : './' + [...plan.rootFolder, 'vite.config.js'].join('/'))}`)
  // console.info(`   - Install ${cyan('vite dependencies')} to ${dim('...')} ${yellow(plan.rootFolder.length === 0 ? './package.json' : './' + [...plan.rootFolder, 'package.json'].join('/'))}`)
  console.info(`   - Create ${cyan('main.js')} in ${dim('..............')} ${yellow(plan.elmRootFolder.length === 0 ? './main.js' : './' + [...plan.elmRootFolder,'main.js'].join('/'))}`)
  console.info(`   - Create ${cyan('all Elm files')} in ${dim('........')} ${yellow(plan.elmRootFolder.length === 0 ? './src/**' : './' + [...plan.elmRootFolder,'src/**'].join('/'))}`)
  console.info('')

  const response = await prompts(
    [{
      type: 'confirm',
      name: 'isOkay',
      message: 'Does this plan look okay?',      
    }]
  )
  return response.isOkay
}

const generateNewProject = async (plan) => {
  let rootFolder = path.join(process.cwd(), ...plan.rootFolder)
  let elmRootFolder = path.join(process.cwd(),...plan.elmRootFolder)

  // Add elm.json
  await Files.copyPasteFile({
    source: path.join(__dirname, 'template', 'elm.json'),
    destination: path.join(rootFolder, 'elm.json')
  })

  // Add vite.config.js
  await Files.copyPasteFile({
    source: path.join(__dirname, 'template', 'vite.config.js'),
    destination: path.join(rootFolder, 'vite.config.js')
  })

  // Install vite dependencies
  console.log(`\n  Please run the following command: \n\n    npm install -D vite vite-plugin-elm-watch`)

  // Create main.js
  await Files.copyPasteFile({
    source: path.join(__dirname, 'template', 'elmProject', 'main.js'),
    destination: path.join(elmRootFolder, 'main.js')
  })

  // Create Elm files
  await Files.copyPasteFolder({
    source: path.join(__dirname, 'template', 'elmProject', 'src'),
    destination: path.join(elmRootFolder)
  })
  
}