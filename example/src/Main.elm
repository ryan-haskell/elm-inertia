module Main exposing (main)

import Browser exposing (Document)
import Browser.Events
import Effect exposing (Effect)
import Html exposing (Html)
import Http
import Inertia
import Interop
import Json.Decode
import Page
import Process
import Shared
import Task
import Url exposing (Url)



-- PROGRAM


type alias Model =
    Inertia.Model Page.Model Shared.Model


type alias Msg =
    Inertia.Msg Page.Msg Shared.Msg


main : Inertia.Program Model Msg
main =
    Inertia.program
        { shared =
            { init = Shared.init
            , update = Shared.update
            , subscriptions = Shared.subscriptions
            , onNavigationError = Shared.NavigationError
            }
        , page =
            { init = Page.init
            , update = Page.update
            , view = Page.view
            , subscriptions = Page.subscriptions
            , onPropsChanged = Page.onPropsChanged
            }
        , interop =
            { decoder = Interop.decoder
            , onRefreshXsrfToken = Interop.onRefreshXsrfToken
            , onXsrfTokenRefreshed = Interop.onXsrfTokenRefreshed
            }
        , effect =
            { fromCustomEffectToCmd = fromCustomEffectToCmd
            , fromShared = Effect.mapCustomEffect
            , fromPage = Effect.mapCustomEffect
            }
        }


fromCustomEffectToCmd :
    { shared : Shared.Model
    , url : Url
    , fromSharedMsg : Shared.Msg -> msg
    }
    -> Effect.CustomEffect msg
    -> Cmd msg
fromCustomEffectToCmd context customEffect =
    Effect.switch customEffect
        { onSendDelayedMsg =
            \float msg ->
                Process.sleep float
                    |> Task.perform (\_ -> msg)
        }
