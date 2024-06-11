import path from 'path'
import { Files } from './_files.js'

const template = (pageModule = '', pageFolder) => `
module ${pageFolder}.${pageModule} exposing
    ( Props, decoder
    , Model, init, onPropsChanged
    , Msg, update, subscriptions
    , view
    )

{-|

@docs Props, decoder
@docs Model, init, onPropsChanged
@docs Msg, update, subscriptions
@docs view

-}

import Browser
import Effect exposing (Effect)
import Html exposing (..)
import Json.Decode
import Shared
import Url exposing (Url)



-- PROPS


type alias Props =
    {}


decoder : Json.Decode.Decoder Props
decoder =
    Json.Decode.succeed {}



-- MODEL


type alias Model =
    {}


init : Shared.Model -> Url -> Props -> ( Model, Effect Msg )
init shared url props =
    ( {}
    , Effect.none
    )


onPropsChanged : Shared.Model -> Url -> Props -> Model -> ( Model, Effect Msg )
onPropsChanged shared url props model =
    ( model, Effect.none )



-- UPDATE


type Msg
    = NoOp


update : Shared.Model -> Url -> Props -> Msg -> Model -> ( Model, Effect Msg )
update shared url props msg model =
    case msg of
        NoOp ->
            ( model, Effect.none )


subscriptions : Shared.Model -> Url -> Props -> Model -> Sub Msg
subscriptions shared url props model =
    Sub.none



-- VIEW


view : Shared.Model -> Url -> Props -> Model -> Browser.Document Msg
view shared url props model =
    { title = "${pageModule}"
    , body =
        [ h1 [] [ text "${pageModule}" ]
        , p [] [ text "This app is powered by elm-inertia!" ]
        ]
    }
`.trimStart()

export default async (userInput = '') => {
  // 1. Check for presence of `src/Page` folder
  let pagesFolder = path.join(process.cwd(), 'src', 'Page')
  let foundPagesFolder = await Files.exists(pagesFolder)

  if (!foundPagesFolder) {
    console.warn(`‼️ Could not find "src/Page" folder in the current directory.`)
    return
  }

  // 2. Normalize the user input so it works with "." or "/"
  if (!userInput) {
    console.warn(`‼️ Please provide a name like "Dashboard" or "Organizations/Index"`)
    return
  }
  let pageModuleName = userInput
  if (userInput.includes('/')) {
    pageModuleName = userInput.split('/').join('.')
  }

  // Create a new Page file
  const pageFolder = 'Pages'
  await Files.createFile({
    name: `src/${pageFolder}/${pageModuleName.split('.').join('/')}.elm`,
    content: template(pageModuleName, pageFolder)
  })
}