module Main exposing (main)

import Browser.Events
import Effect exposing (Effect)
import Inertia
import Interop
import Json.Decode
import Pages
import Shared
import Url exposing (Url)



-- PROGRAM


type alias Model =
    Inertia.Model Pages.Model Shared.Model


type alias Msg =
    Inertia.Msg Pages.Msg Shared.Msg


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
            { init = Pages.init
            , update = Pages.update
            , view = Pages.view
            , subscriptions = Pages.subscriptions
            , onPropsChanged = Pages.onPropsChanged
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
    case customEffect of
        Effect.ReportFlagsDecodeError error ->
            Interop.onFlagsDecodeError (Json.Decode.errorToString error)
