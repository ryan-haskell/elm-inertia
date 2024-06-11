module Pages.Error404 exposing
    ( Model, init
    , Msg, update, subscriptions
    , view
    )

{-|

@docs Model, init
@docs Msg, update, subscriptions
@docs view

-}

import Browser
import Effect exposing (Effect)
import Html exposing (..)
import Shared
import Url exposing (Url)



-- MODEL


type alias Model =
    {}


init : Shared.Model -> Url -> ( Model, Effect Msg )
init shared url =
    ( {}
    , Effect.none
    )


onPropsChanged : Shared.Model -> Url -> Model -> ( Model, Effect Msg )
onPropsChanged shared url model =
    ( model, Effect.none )



-- UPDATE


type Msg
    = NoOp


update : Shared.Model -> Url -> Msg -> Model -> ( Model, Effect Msg )
update shared url msg model =
    case msg of
        NoOp ->
            ( model, Effect.none )


subscriptions : Shared.Model -> Url -> Model -> Sub Msg
subscriptions shared url model =
    Sub.none



-- VIEW


view : Shared.Model -> Url -> Model -> Browser.Document Msg
view shared url model =
    { title = "404"
    , body =
        [ h1 [] [ text "404" ]
        , p [] [ text "This page wasn't found" ]
        ]
    }
