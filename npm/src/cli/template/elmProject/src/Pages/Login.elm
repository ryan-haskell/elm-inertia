module Pages.Login exposing
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
    { title = "Login"
    , body =
        [ h1 [] [ text "Login" ]
        , p [] [ text "This app is powered by elm-inertia!" ]
        ]
    }
