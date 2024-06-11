module Main exposing (main)

import Browser.Events
import Effect exposing (Effect)
import Inertia
import Interop
import Json.Decode
import Page
import Shared
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
    case customEffect of
        Effect.ReportFlagsDecodeError error ->
            Interop.onFlagsDecodeError (Json.Decode.errorToString error)
