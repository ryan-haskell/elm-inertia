module Shared exposing (Model, Msg(..), init, subscriptions, update)

import Browser.Events
import Effect exposing (Effect)
import Http
import Interop exposing (Flags)
import Json.Decode
import Url exposing (Url)


type alias Model =
    { isMobile : Bool
    }


type Msg
    = NavigationError { url : Url, error : Http.Error }
    | Resize Int Int


init : Result Json.Decode.Error Flags -> Url -> ( Model, Effect Msg )
init flagsResult url =
    case flagsResult of
        Ok flags ->
            ( { isMobile = flags.window.width < 740 }
            , Effect.none
            )

        Err reason ->
            ( { isMobile = False }
            , Effect.reportFlagsDecodeError reason
            )


update : Url -> Msg -> Model -> ( Model, Effect Msg )
update url msg model =
    case msg of
        NavigationError error ->
            ( model
            , Effect.none
            )

        Resize width height ->
            ( { model | isMobile = width < 740 }
            , Effect.none
            )


subscriptions : Url -> Model -> Sub Msg
subscriptions url model =
    Browser.Events.onResize Resize
