module Pages.Error500 exposing
    ( Info
    , Model, init
    , Msg, update, subscriptions
    , view
    )

{-|

@docs Info
@docs Model, init
@docs Msg, update, subscriptions
@docs view

-}

import Browser
import Effect exposing (Effect)
import Html exposing (..)
import Inertia exposing (PageObject)
import Json.Decode
import Shared
import Url exposing (Url)



-- INFO ON THE ERROR


type alias Info =
    { pageObject : PageObject Json.Decode.Value
    , error : Json.Decode.Error
    }



-- MODEL


type alias Model =
    {}


init : Shared.Model -> Url -> Info -> ( Model, Effect Msg )
init shared url error =
    ( {}
    , Effect.none
    )



-- UPDATE


type Msg
    = NoOp


update : Shared.Model -> Url -> Info -> Msg -> Model -> ( Model, Effect Msg )
update shared url error msg model =
    case msg of
        NoOp ->
            ( model, Effect.none )


subscriptions : Shared.Model -> Url -> Info -> Model -> Sub Msg
subscriptions shared url error model =
    Sub.none



-- VIEW


view : Shared.Model -> Url -> Info -> Model -> Browser.Document Msg
view shared url { error } model =
    { title = "500"
    , body =
        [ h1 [] [ text "500" ]
        , p [] [ text "The server returned an unexpected response." ]
        , pre []
            [ code [] [ text (Json.Decode.errorToString error) ]
            ]
        ]
    }
