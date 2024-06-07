port module Inertia.Example exposing (main)

import Browser exposing (Document)
import Browser.Events
import Html exposing (Html)
import Http
import Inertia.Effect as Effect exposing (Effect)
import Inertia.PageData exposing (PageData)
import Inertia.Program exposing (Program)
import Json.Decode
import Url exposing (Url)



-- src/Main.elm


main : Program SharedModel SharedMsg PageModel PageMsg
main =
    Inertia.Program.new
        { shared =
            { init = sharedInit
            , update = sharedUpdate
            , subscriptions = sharedSubscriptions
            , onNavigationError = NavigationError
            , effectToCmd = toCmd
            }
        , page =
            { init = pageInit
            , update = pageUpdate
            , subscriptions = pageSubscriptions
            , view = pageView
            , onPropsChanged = pageOnPropsChanged
            , effectToCmd = toCmd
            }
        , interop =
            { decoder = decoder
            , onRefreshXsrfToken = onRefreshXsrfToken
            , onXsrfTokenRefreshed = onXsrfTokenRefreshed
            }
        }



-- EFFECTS


type alias Msg =
    Inertia.Program.Msg PageMsg SharedMsg


toCmd :
    { fromInertiaEffect : Effect Msg -> Cmd Msg
    , fromSharedMsg : SharedMsg -> Msg
    , shared : SharedModel
    , url : Url
    }
    -> (someMsg -> Msg)
    -> Effect someMsg
    -> Cmd Msg
toCmd props toMsg effect =
    effect
        |> Effect.map toMsg
        |> props.fromInertiaEffect



-- src/Interop.elm


type alias Flags =
    { window : WindowSize
    }


decoder : Json.Decode.Decoder Flags
decoder =
    Json.Decode.map Flags
        (Json.Decode.field "window" windowSizeDecoder)


type alias WindowSize =
    { width : Float
    , height : Float
    }


windowSizeDecoder : Json.Decode.Decoder WindowSize
windowSizeDecoder =
    Json.Decode.map2 WindowSize
        (Json.Decode.field "width" Json.Decode.float)
        (Json.Decode.field "height" Json.Decode.float)


port onRefreshXsrfToken : () -> Cmd msg


port onXsrfTokenRefreshed : (String -> msg) -> Sub msg



-- src/Pages.elm


type PageModel
    = Model_Dashboard {}
    | Model_404 {}


type PageMsg
    = Msg_Dashboard {}
    | Msg_404 {}


pageInit :
    SharedModel
    -> Url
    -> PageData Json.Decode.Value
    -> ( PageModel, Effect PageMsg )
pageInit shared url pageData =
    case pageData.component of
        "Dashboard/Index" ->
            ( Model_Dashboard {}, Effect.none )

        _ ->
            ( Model_404 {}, Effect.none )


pageUpdate :
    SharedModel
    -> Url
    -> PageData Json.Decode.Value
    -> PageMsg
    -> PageModel
    -> ( PageModel, Effect PageMsg )
pageUpdate shared url pageData msg model =
    case ( msg, model ) of
        ( Msg_Dashboard pageMsg, Model_Dashboard pageModel ) ->
            -- Pages.Dashboard.update...
            ( model, Effect.none )

        ( Msg_404 pageMsg, Model_404 pageModel ) ->
            -- Pages.Error404.update...
            ( model, Effect.none )

        _ ->
            ( model, Effect.none )


pageSubscriptions : SharedModel -> Url -> PageData Json.Decode.Value -> PageModel -> Sub PageMsg
pageSubscriptions shared url pageData pageModel =
    case pageModel of
        Model_Dashboard {} ->
            -- Pages.Dashboard.subscriptions...
            Sub.none

        Model_404 {} ->
            -- Pages.404.subscriptions...
            Sub.none


pageView : SharedModel -> Url -> PageData Json.Decode.Value -> PageModel -> Document PageMsg
pageView shared url pageData pageModel =
    case pageModel of
        Model_Dashboard {} ->
            -- Pages.Dashboard.subscriptions...
            { title = "Dashboard", body = [ Html.text "Dashboard page" ] }

        Model_404 {} ->
            -- Pages.404.subscriptions...
            { title = "404", body = [ Html.text "404 page" ] }


pageOnPropsChanged :
    SharedModel
    -> Url
    -> PageData Json.Decode.Value
    -> PageModel
    -> ( PageModel, Effect PageMsg )
pageOnPropsChanged shared url pageData model =
    case model of
        Model_Dashboard pageModel ->
            -- Pages.Dashboard.onPropsChanged...
            ( model, Effect.none )

        Model_404 pageModel ->
            -- Pages.Error404.onPropsChanged...
            ( model, Effect.none )



-- src/Shared.elm


type alias SharedModel =
    { isMobile : Bool
    }


type SharedMsg
    = NavigationError { url : Url, error : Http.Error }
    | Resize Int Int


sharedInit : Result Json.Decode.Error Flags -> Url -> ( SharedModel, Effect SharedMsg )
sharedInit flagsResult url =
    ( case flagsResult of
        Ok flags ->
            { isMobile = flags.window.width < 740 }

        Err reason ->
            { isMobile = False }
    , Effect.none
    )


sharedUpdate : Url -> SharedMsg -> SharedModel -> ( SharedModel, Effect SharedMsg )
sharedUpdate url msg model =
    case msg of
        NavigationError error ->
            ( model
            , Effect.none
            )

        Resize width height ->
            ( { model | isMobile = width < 740 }
            , Effect.none
            )


sharedSubscriptions : Url -> SharedModel -> Sub SharedMsg
sharedSubscriptions url model =
    Browser.Events.onResize Resize
