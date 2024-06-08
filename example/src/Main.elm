module Main exposing (main)

import Browser exposing (Document)
import Browser.Events
import Html exposing (Html)
import Http
import Inertia
import Inertia.Effect as Effect exposing (Effect)
import Interop
import Json.Decode
import Page
import Shared
import Url exposing (Url)



-- PROGRAM


type alias Program =
    Inertia.Program Model Msg


type alias Model =
    Inertia.Model Page.Model Shared.Model


type alias Msg =
    Inertia.Msg Page.Msg Shared.Msg


main : Program
main =
    Inertia.program
        { shared = sharedModule
        , page = pageModule
        , interop =
            { decoder = Interop.decoder
            , onRefreshXsrfToken = Interop.onRefreshXsrfToken
            , onXsrfTokenRefreshed = Interop.onXsrfTokenRefreshed
            }
        , effect =
            { fromPage = fromEffectToCmd
            , fromShared = fromEffectToCmd
            }
        }



-- PAGE


type alias PageModule =
    Inertia.PageModule Shared.Model Page.Model Page.Msg (Effect Page.Msg)


pageModule : PageModule
pageModule =
    { init = Page.init
    , update = Page.update
    , view = Page.view
    , subscriptions = Page.subscriptions
    , onPropsChanged = Page.onPropsChanged
    }



-- SHARED


type alias SharedModule =
    Inertia.SharedModule
        Interop.Flags
        Shared.Model
        Shared.Msg
        (Effect Shared.Msg)


sharedModule : SharedModule
sharedModule =
    { init = Shared.init
    , update = Shared.update
    , subscriptions = Shared.subscriptions
    , onNavigationError = Shared.NavigationError
    }



-- EFFECT


type alias EffectContext =
    Inertia.EffectContext Shared.Model Shared.Msg Page.Msg


fromEffectToCmd :
    EffectContext
    -> (someMsg -> Msg)
    -> Effect someMsg
    -> Cmd Msg
fromEffectToCmd context toMsg effect =
    effect
        |> Effect.map toMsg
        |> context.fromInertiaEffect
