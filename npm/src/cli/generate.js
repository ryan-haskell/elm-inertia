import path from 'path'
import { Files } from './_files.js'

let template = (pageModules, pageFolder) => `
module ${pageFolder} exposing (Model, Msg, init, onPropsChanged, subscriptions, update, view)

import Browser exposing (Document)
import Effect exposing (Effect)
import Html
import Inertia exposing (PageObject)
import Json.Decode exposing (Value)
${toPageImports(pageModules, pageFolder)}
import Shared
import Url exposing (Url)


${toModelCustomType(pageModules, pageFolder)}


${toMsgCustomType(pageModules, pageFolder)}


init : Shared.Model -> Url -> PageObject Value -> ( Model, Effect Msg )
init shared url pageObject =
${toInitBody(pageModules, pageFolder)}


update : Shared.Model -> Url -> PageObject Value -> Msg -> Model -> ( Model, Effect Msg )
update shared url pageObject msg model =
    case ( msg, model ) of
        ${toUpdateCaseBranches(pageModules, pageFolder)}( Msg_Error404 pageMsg, Model_Error404 page ) ->
            let
                ( pageModel, pageEffect ) =
                    ${pageFolder}.Error404.update shared url pageMsg page.model
            in
            ( Model_Error404 { page | model = pageModel }
            , Effect.map Msg_Error404 pageEffect
            )

        ( Msg_Error500 pageMsg, Model_Error500 page ) ->
            let
                ( pageModel, pageEffect ) =
                    ${pageFolder}.Error500.update shared url page.info pageMsg page.model
            in
            ( Model_Error500 { page | model = pageModel }
            , Effect.map Msg_Error500 pageEffect
            )

        _ ->
            ( model, Effect.none )


subscriptions : Shared.Model -> Url -> PageObject Value -> Model -> Sub Msg
subscriptions shared url pageObject model =
    case model of
        ${toSubscriptionsCaseBranches(pageModules, pageFolder)}Model_Error404 page ->
            ${pageFolder}.Error404.subscriptions shared url page.model
                |> Sub.map Msg_Error404

        Model_Error500 page ->
            ${pageFolder}.Error500.subscriptions shared url page.info page.model
                |> Sub.map Msg_Error500


view : Shared.Model -> Url -> PageObject Value -> Model -> Document Msg
view shared url pageObject model =
    case model of
        ${toViewCaseBranches(pageModules, pageFolder)}Model_Error404 page ->
            ${pageFolder}.Error404.view shared url page.model
                |> mapDocument Msg_Error404

        Model_Error500 page ->
            ${pageFolder}.Error500.view shared url page.info page.model
                |> mapDocument Msg_Error500


onPropsChanged :
    Shared.Model
    -> Url
    -> PageObject Value
    -> Model
    -> ( Model, Effect Msg )
onPropsChanged shared url pageObject model =
    case model of
        ${toOnPropsChangedCaseBranches(pageModules, pageFolder)}Model_Error404 page ->
            ( model, Effect.none )

        Model_Error500 page ->
            ( model, Effect.none )



-- HELPERS


mapDocument : (a -> b) -> Browser.Document a -> Browser.Document b
mapDocument fn doc =
    { title = doc.title
    , body = List.map (Html.map fn) doc.body
    }


onPropsChangedForPage :
    Shared.Model
    -> Url
    -> PageObject Value
    -> { props : props, model : model }
    ->
        { decoder : Json.Decode.Decoder props
        , onPropsChanged : Shared.Model -> Url -> props -> model -> ( model, Effect msg )
        , toModel : { props : props, model : model } -> Model
        , toMsg : msg -> Msg
        }
    -> ( Model, Effect Msg )
onPropsChangedForPage shared url pageObject page options =
    case Json.Decode.decodeValue options.decoder pageObject.props of
        Ok props ->
            let
                ( pageModel, pageEffect ) =
                    options.onPropsChanged shared url props page.model
            in
            ( options.toModel { props = props, model = pageModel }
            , Effect.map options.toMsg pageEffect
            )

        Err jsonDecodeError ->
            let
                info : ${pageFolder}.Error500.Info
                info =
                    { pageObject = pageObject, error = jsonDecodeError }

                ( pageModel, pageEffect ) =
                    ${pageFolder}.Error500.init shared url info
            in
            ( Model_Error500 { info = info, model = pageModel }
            , Effect.map Msg_Error500 pageEffect
            )


initForPage :
    Shared.Model
    -> Url
    -> PageObject Value
    ->
        { decoder : Json.Decode.Decoder props
        , init : Shared.Model -> Url -> props -> ( model, Effect msg )
        , toModel : { props : props, model : model } -> Model
        , toMsg : msg -> Msg
        }
    -> ( Model, Effect Msg )
initForPage shared url pageObject options =
    case Json.Decode.decodeValue options.decoder pageObject.props of
        Ok props ->
            let
                ( pageModel, pageEffect ) =
                    options.init shared url props
            in
            ( options.toModel { props = props, model = pageModel }
            , Effect.map options.toMsg pageEffect
            )

        Err jsonDecodeError ->
            let
                info : ${pageFolder}.Error500.Info
                info =
                    { pageObject = pageObject, error = jsonDecodeError }

                ( pageModel, pageEffect ) =
                    ${pageFolder}.Error500.init shared url info
            in
            ( Model_Error500 { info = info, model = pageModel }
            , Effect.map Msg_Error500 pageEffect
            )
`.trimStart()

/**
 * @example
 * 
 *    toModelCustomType([
 *      'Dashboard',
 *      'Login',
 *      'Organizations.Index',
 *    ])
 * 
 * @param {string[]} pageModules 
 * @returns {string}
 */
const toModelCustomType = (pageModules = [], pageFolder) =>{
  const separator = `\n    | `

  const toVariant = (pageModule) =>
    `Model_${toSnakeCase(pageModule)} { props : ${pageFolder}.${pageModule}.Props, model : ${pageFolder}.${pageModule}.Model }`

  return (pageModules.length === 0)
    ? `type Model
    = Model_Error404 { model : ${pageFolder}.Error404.Model }
    | Model_Error500 { info : ${pageFolder}.Error500.Info, model : ${pageFolder}.Error500.Model }`
    : `type Model
    = ${pageModules.map(toVariant).join(separator)}
    | Model_Error404 { model : ${pageFolder}.Error404.Model }
    | Model_Error500 { info : ${pageFolder}.Error500.Info, model : ${pageFolder}.Error500.Model }`
}


/**
 * @example
 * 
 *    toMsgCustomType([
 *      'Dashboard',
 *      'Login',
 *      'Organizations.Index',
 *    ])
 * 
 * @param {string[]} pageModules 
 * @returns {string}
 */
const toMsgCustomType = (pageModules = [], pageFolder) =>{
  const separator = `\n    | `

  const toVariant = (pageModule) =>
    `Msg_${toSnakeCase(pageModule)} ${pageFolder}.${pageModule}.Msg`

  return (pageModules.length === 0)
    ? `type Msg
    = Msg_Error404 ${pageFolder}.Error404.Msg
    | Msg_Error500 ${pageFolder}.Error500.Msg`
    : `type Msg
    = ${pageModules.map(toVariant).join(separator)}
    | Msg_Error404 ${pageFolder}.Error404.Msg
    | Msg_Error500 ${pageFolder}.Error500.Msg`
}


/**
 * @example
 * 
 *    toModelCustomType([
 *      'Dashboard',
 *      'Login',
 *      'Organizations.Index',
 *    ])
 * 
 * @param {string[]} pageModules 
 * @returns {string}
 */
const toPageImports = (pageModules = [], pageFolder) => 
  pageModules.concat(['Error404', 'Error500'])
    .map(pageModule => `import ${pageFolder}.${pageModule}`)
    .join('\n')


const toInitBody = (pageModules = [], pageFolder) => {

  if (pageModules.length === 0) {
    return `    let
        ( pageModel, pageEffect ) =
            ${pageFolder}.Error404.init shared url
    in
    ( Model_Error404 { model = pageModel }
    , Effect.map Msg_Error404 pageEffect
    )`
  }

  const separator = `\n\n        `

  const toCaseBranch = (pageModule = '') => {
    return `"${toSlashCase(pageModule)}" ->
            initForPage shared url pageObject <|
                { decoder = ${pageFolder}.${pageModule}.decoder
                , init = ${pageFolder}.${pageModule}.init
                , toModel = Model_${toSnakeCase(pageModule)}
                , toMsg = Msg_${toSnakeCase(pageModule)}
                }`
  }

  return `    case pageObject.component of
        ${pageModules.map(toCaseBranch).join(separator)}

        _ ->
            let
                ( pageModel, pageEffect ) =
                    ${pageFolder}.Error404.init shared url
            in
            ( Model_Error404 { model = pageModel }
            , Effect.map Msg_Error404 pageEffect
            )`
}


const toUpdateCaseBranches = (pageModules = [], pageFolder) => {
  if (pageModules.length === 0) return ''

  const separator = `\n\n        `

  const toCaseBranch = (pageModule = '') => {
    return `( Msg_${toSnakeCase(pageModule)} pageMsg, Model_${toSnakeCase(pageModule)} page ) ->
            let
                ( pageModel, pageEffect ) =
                    ${pageFolder}.${pageModule}.update shared url page.props pageMsg page.model
            in
            ( Model_${toSnakeCase(pageModule)} { page | model = pageModel }
            , Effect.map Msg_${toSnakeCase(pageModule)} pageEffect
            )`
  }

  return pageModules.map(toCaseBranch).join(separator) + separator
}


const toSubscriptionsCaseBranches = (pageModules = [], pageFolder) => {
  if (pageModules.length === 0) return ''

  const separator = `\n\n        `

  const toCaseBranch = (pageModule = '') => {
    return `Model_${toSnakeCase(pageModule)} page ->
            ${pageFolder}.${pageModule}.subscriptions shared url page.props page.model
                |> Sub.map Msg_${toSnakeCase(pageModule)}`
  }

  return pageModules.map(toCaseBranch).join(separator) + separator
}


const toViewCaseBranches = (pageModules = [], pageFolder) => {
  if (pageModules.length === 0) return ''

  const separator = `\n\n        `

  const toCaseBranch = (pageModule = '') => {
    return `Model_${toSnakeCase(pageModule)} page ->
            ${pageFolder}.${pageModule}.view shared url page.props page.model
                |> mapDocument Msg_${toSnakeCase(pageModule)}`
  }

  return pageModules.map(toCaseBranch).join(separator) + separator
}


const toOnPropsChangedCaseBranches = (pageModules = [], pageFolder) => {
  if (pageModules.length === 0) return ''

  const separator = `\n\n        `

  const toCaseBranch = (pageModule = '') => {
    return `Model_${toSnakeCase(pageModule)} page ->
            onPropsChangedForPage shared url pageObject page <|
                { decoder = ${pageFolder}.${pageModule}.decoder
                , onPropsChanged = ${pageFolder}.${pageModule}.onPropsChanged
                , toModel = Model_${toSnakeCase(pageModule)}
                , toMsg = Msg_${toSnakeCase(pageModule)}
                }`
  }

  return pageModules.map(toCaseBranch).join(separator) + separator
}


// UTILITIES

/**
 * @example 
 *  toSnakeCase('Dashboard') == 'Dashboard'
 *  toSnakeCase('Organizations.Index') == 'Organizations_Index'
 * @param {string} input
 * @returns {string}
 */ 
const toSnakeCase = (dotSeparatedString = '') =>
  dotSeparatedString.split('.').join('_')


/**
 * @example 
 *  toSlashCase('Dashboard') == 'Dashboard'
 *  toSlashCase('Organizations.Index') == 'Organizations/Index'
 * @param {string} input
 * @returns {string}
 */ 
const toSlashCase = (dotSeparatedString = '') =>
  dotSeparatedString.split('.').join('/')



export default async () => {
  // 1. Check for presence of `src/Page` folder
  let pagesFolder = path.join(process.cwd(), 'src', 'Page')
  let foundPagesFolder = await Files.exists(pagesFolder)

  if (!foundPagesFolder) {
    console.warn(`‼️ Could not find "src/Page" folder in the current directory.`)
    return
  }

  // 2. List all Elm files in the pages folder
  let pageFilepaths = await Files.listElmFilepathsInFolder(pagesFolder)
  let pageModuleNames = pageFilepaths
    .map(fp => fp.split(path.sep).join('.'))
    .filter(name => name !== 'Error404' && name !== 'Error500')
    .sort()

    
  // Create a new Page file
  const pageFolder = 'Pages'
  await Files.createFile({
    name: `src/${pageFolder}.elm`,
    content: template(pageModuleNames, pageFolder)
  })
}