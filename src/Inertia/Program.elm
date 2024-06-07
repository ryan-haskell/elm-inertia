module Inertia.Program exposing
    ( Program, new
    , Msg
    )

{-|

@docs Program, new
@docs Msg

-}

import Browser exposing (Document, UrlRequest)
import Browser.Dom
import Browser.Events
import Browser.Navigation as Nav exposing (Key)
import Html exposing (Html)
import Http
import Inertia.Effect as Effect exposing (Effect)
import Inertia.HttpRequest
import Inertia.PageData exposing (PageData)
import Json.Decode
import Json.Encode
import Process
import Task
import Url exposing (Url)


type alias Program sharedModel sharedMsg pageModel pageMsg =
    Platform.Program
        Json.Decode.Value
        (Model pageModel sharedModel)
        (Msg pageMsg sharedMsg)


new :
    { shared :
        { init : Result Json.Decode.Error flags -> Url -> ( sharedModel, sharedEffect )
        , update : Url -> sharedMsg -> sharedModel -> ( sharedModel, sharedEffect )
        , subscriptions : Url -> sharedModel -> Sub sharedMsg
        , onNavigationError : { url : Url, error : Http.Error } -> sharedMsg
        , effectToCmd :
            { fromInertiaEffect : Effect (Msg pageMsg sharedMsg) -> Cmd (Msg pageMsg sharedMsg)
            , fromSharedMsg : sharedMsg -> Msg pageMsg sharedMsg
            , shared : sharedModel
            , url : Url
            }
            -> (sharedMsg -> Msg pageMsg sharedMsg)
            -> sharedEffect
            -> Cmd (Msg pageMsg sharedMsg)
        }
    , page :
        { init : sharedModel -> Url -> PageData Json.Decode.Value -> ( pageModel, pageEffect )
        , update : sharedModel -> Url -> PageData Json.Decode.Value -> pageMsg -> pageModel -> ( pageModel, pageEffect )
        , subscriptions : sharedModel -> Url -> PageData Json.Decode.Value -> pageModel -> Sub pageMsg
        , view : sharedModel -> Url -> PageData Json.Decode.Value -> pageModel -> Browser.Document pageMsg
        , onPropsChanged : sharedModel -> Url -> PageData Json.Decode.Value -> pageModel -> ( pageModel, pageEffect )
        , effectToCmd :
            { fromInertiaEffect : Effect (Msg pageMsg sharedMsg) -> Cmd (Msg pageMsg sharedMsg)
            , fromSharedMsg : sharedMsg -> Msg pageMsg sharedMsg
            , shared : sharedModel
            , url : Url
            }
            -> (pageMsg -> Msg pageMsg sharedMsg)
            -> pageEffect
            -> Cmd (Msg pageMsg sharedMsg)
        }
    , interop :
        { decoder : Json.Decode.Decoder flags
        , onRefreshXsrfToken : () -> Cmd (Msg pageMsg sharedMsg)
        , onXsrfTokenRefreshed : (String -> Msg pageMsg sharedMsg) -> Sub (Msg pageMsg sharedMsg)
        }
    }
    -> Program sharedModel sharedMsg pageModel pageMsg
new options =
    Browser.application
        { init = init options
        , update = update options
        , view = view options
        , subscriptions = subscriptions options
        , onUrlChange = UrlChanged >> Inertia
        , onUrlRequest = UrlRequested LinkClicked >> Inertia
        }



-- FLAGS


type alias Flags flags =
    { inertia : InertiaFlags
    , user : flags
    }


type alias InertiaFlags =
    { xsrfToken : String
    , pageData : PageData Json.Decode.Value
    }


interiaFlagsDecoder : Json.Decode.Decoder InertiaFlags
interiaFlagsDecoder =
    Json.Decode.map2 InertiaFlags
        (Json.Decode.field "xsrfToken" Json.Decode.string)
        (Json.Decode.field "pageData" (Inertia.PageData.decoder Json.Decode.value))


inertiaFlagsFallback : InertiaFlags
inertiaFlagsFallback =
    -- Only occurs if application is not initialized with "elm-inertia.js"
    { xsrfToken = "???"
    , pageData =
        { component = "???"
        , props = Json.Encode.null
        , url = "???"
        , version = "???"
        }
    }


strictDecodeFlags :
    Options flags sharedModel sharedMsg sharedEffect pageModel pageMsg pageEffect
    -> Json.Decode.Value
    -> Result Json.Decode.Error (Flags flags)
strictDecodeFlags options json =
    Json.Decode.decodeValue
        (Json.Decode.map2 Flags
            (Json.Decode.field "inertia" interiaFlagsDecoder)
            (Json.Decode.field "user" options.interop.decoder)
        )
        json



-- MODEL


type alias Model page shared =
    { inertia : InertiaModel
    , page : page
    , shared : shared
    }


type alias InertiaModel =
    { url : Url
    , key : Key
    , pageData : PageData Json.Decode.Value
    , xsrfToken : String
    , urlRequestSource : UrlRequestSource
    }


init :
    Options flags sharedModel sharedMsg sharedEffect pageModel pageMsg pageEffect
    -> Json.Decode.Value
    -> Url
    -> Key
    ->
        ( Model pageModel sharedModel
        , Cmd (Msg pageMsg sharedMsg)
        )
init options json url key =
    let
        ( inertiaFlags, userFlagsResult ) =
            case strictDecodeFlags options json of
                Ok flags ->
                    ( flags.inertia
                    , Ok flags.user
                    )

                Err jsonDecodeError ->
                    ( Json.Decode.decodeValue (Json.Decode.field "inertia" interiaFlagsDecoder) json
                        |> Result.withDefault inertiaFlagsFallback
                    , Err jsonDecodeError
                    )

        ( shared, sharedEffect ) =
            options.shared.init userFlagsResult url

        ( page, pageEffect ) =
            options.page.init shared url inertiaFlags.pageData

        inertia : InertiaModel
        inertia =
            { url = url
            , key = key
            , pageData = inertiaFlags.pageData
            , xsrfToken = inertiaFlags.xsrfToken
            , urlRequestSource = AppLoaded
            }

        model : Model pageModel sharedModel
        model =
            { inertia = inertia
            , page = page
            , shared = shared
            }
    in
    ( model
    , Cmd.batch
        [ options.page.effectToCmd
            { fromInertiaEffect = fromInertiaEffect options model.inertia
            , fromSharedMsg = Shared
            , shared = model.shared
            , url = model.inertia.url
            }
            Page
            pageEffect
        , options.shared.effectToCmd
            { fromInertiaEffect = fromInertiaEffect options model.inertia
            , fromSharedMsg = Shared
            , shared = model.shared
            , url = model.inertia.url
            }
            Shared
            sharedEffect
        ]
    )



-- UPDATE


type Msg pageMsg sharedMsg
    = Page pageMsg
    | Shared sharedMsg
    | Inertia (InertiaMsg (Msg pageMsg sharedMsg))


type InertiaMsg msg
    = UrlChanged Url
    | UrlRequested UrlRequestSource UrlRequest
    | InertiaPageDataResponded Url (Result Http.Error (PageData Json.Decode.Value))
    | XsrfTokenRefreshed String
    | ScrollFinished
    | PropsChanged (PageData Json.Decode.Value) msg


type UrlRequestSource
    = AppLoaded
    | LinkClicked
    | Http (PageData Json.Decode.Value)


update :
    Options flags sharedModel sharedMsg sharedEffect pageModel pageMsg pageEffect
    -> Msg pageMsg sharedMsg
    -> Model pageModel sharedModel
    ->
        ( Model pageModel sharedModel
        , Cmd (Msg pageMsg sharedMsg)
        )
update options msg model =
    case msg of
        Page pageMsg ->
            let
                ( pageModel, pageEffect ) =
                    options.page.update model.shared model.inertia.url model.inertia.pageData pageMsg model.page
            in
            ( { model | page = pageModel }
            , options.page.effectToCmd
                { fromInertiaEffect = fromInertiaEffect options model.inertia
                , fromSharedMsg = Shared
                , shared = model.shared
                , url = model.inertia.url
                }
                Page
                pageEffect
            )

        Shared sharedMsg ->
            let
                ( sharedModel, sharedEffect ) =
                    options.shared.update model.inertia.url sharedMsg model.shared
            in
            ( { model | shared = sharedModel }
            , options.shared.effectToCmd
                { fromInertiaEffect = fromInertiaEffect options model.inertia
                , fromSharedMsg = Shared
                , shared = model.shared
                , url = model.inertia.url
                }
                Shared
                sharedEffect
            )

        Inertia inertiaMsg ->
            let
                ( inertiaModel, inertiaCmd, trigger ) =
                    inertiaUpdate options inertiaMsg model.inertia
            in
            case trigger of
                TriggerNone ->
                    ( { model | inertia = inertiaModel }
                    , inertiaCmd
                    )

                TriggerPagePropsChanged pageData ->
                    let
                        ( page, pageEffect ) =
                            options.page.onPropsChanged model.shared model.inertia.url pageData model.page
                    in
                    ( { model | inertia = inertiaModel, page = page }
                    , Cmd.batch
                        [ inertiaCmd
                        , options.page.effectToCmd
                            { fromInertiaEffect = fromInertiaEffect options model.inertia
                            , fromSharedMsg = Shared
                            , shared = model.shared
                            , url = model.inertia.url
                            }
                            Page
                            pageEffect
                        ]
                    )

                TriggerPageInit pageData ->
                    let
                        ( page, pageEffect ) =
                            options.page.init model.shared model.inertia.url pageData
                    in
                    ( { model | inertia = inertiaModel, page = page }
                    , Cmd.batch
                        [ inertiaCmd
                        , options.page.effectToCmd
                            { fromInertiaEffect = fromInertiaEffect options model.inertia
                            , fromSharedMsg = Shared
                            , shared = model.shared
                            , url = model.inertia.url
                            }
                            Page
                            pageEffect
                        ]
                    )


type Trigger
    = TriggerNone
    | TriggerPagePropsChanged (PageData Json.Decode.Value)
    | TriggerPageInit (PageData Json.Decode.Value)


inertiaUpdate :
    Options flags sharedModel sharedMsg sharedEffect pageModel pageMsg pageEffect
    -> InertiaMsg (Msg pageMsg sharedMsg)
    -> InertiaModel
    -> ( InertiaModel, Cmd (Msg pageMsg sharedMsg), Trigger )
inertiaUpdate options msg model =
    case msg of
        UrlRequested urlRequestSource (Browser.Internal url) ->
            ( { model | urlRequestSource = urlRequestSource }
            , Nav.pushUrl model.key (Url.toString url)
            , TriggerNone
            )

        UrlRequested urlRequestSource (Browser.External href) ->
            ( { model | urlRequestSource = urlRequestSource }
            , Nav.load href
            , TriggerNone
            )

        UrlChanged url ->
            if model.url == url then
                ( model
                , Cmd.none
                , TriggerNone
                )

            else
                let
                    performInertiaGetRequest : Cmd (Msg pageMsg sharedMsg)
                    performInertiaGetRequest =
                        Http.request
                            { method = "GET"
                            , url = Url.toString url
                            , headers =
                                [ Http.header "Accept" "text/html, application/xhtml+xml"
                                , Http.header "X-Requested-With" "XMLHttpRequest"
                                , Http.header "X-Inertia" "true"
                                , Http.header "X-XSRF-TOKEN" model.xsrfToken
                                , Http.header "X-Inertia-Version" model.pageData.version
                                ]
                            , body = Http.emptyBody
                            , timeout = Nothing
                            , tracker = Nothing
                            , expect =
                                Http.expectJson
                                    (InertiaPageDataResponded url >> Inertia)
                                    (Inertia.PageData.decoder Json.Decode.value)
                            }
                in
                ( { model | url = url }
                , case model.urlRequestSource of
                    AppLoaded ->
                        performInertiaGetRequest

                    LinkClicked ->
                        performInertiaGetRequest

                    Http newPageData ->
                        if newPageData.component == model.pageData.component then
                            performInertiaGetRequest

                        else
                            Task.succeed (Ok newPageData)
                                |> Task.perform (InertiaPageDataResponded url >> Inertia)
                , TriggerNone
                )

        PropsChanged pageData innerMsg ->
            ( { model | pageData = pageData }
            , Task.succeed innerMsg |> Task.perform identity
            , TriggerPagePropsChanged pageData
            )

        InertiaPageDataResponded url (Ok pageData) ->
            ( { model | pageData = pageData }
            , Cmd.batch
                [ options.interop.onRefreshXsrfToken ()
                , Browser.Dom.setViewportOf "scroll-region" 0 0
                    |> Task.attempt (\_ -> Inertia ScrollFinished)
                ]
            , if model.pageData.component == pageData.component then
                TriggerPagePropsChanged pageData

              else
                TriggerPageInit pageData
            )

        InertiaPageDataResponded url (Err httpError) ->
            ( model
            , options.shared.onNavigationError
                { url = url
                , error = httpError
                }
                |> Task.succeed
                |> Task.perform Shared
            , TriggerNone
            )

        XsrfTokenRefreshed token ->
            ( { model | xsrfToken = token }
            , Cmd.none
            , TriggerNone
            )

        ScrollFinished ->
            ( model
            , Cmd.none
            , TriggerNone
            )



-- SUBSCRIPTIONS


subscriptions :
    Options flags sharedModel sharedMsg sharedEffect pageModel pageMsg pageEffect
    -> Model pageModel sharedModel
    -> Sub (Msg pageMsg sharedMsg)
subscriptions options model =
    Sub.batch
        [ options.page.subscriptions model.shared model.inertia.url model.inertia.pageData model.page
            |> Sub.map Page
        , options.shared.subscriptions model.inertia.url model.shared
            |> Sub.map Shared
        , options.interop.onXsrfTokenRefreshed (XsrfTokenRefreshed >> Inertia)
        ]



-- VIEW


view :
    Options flags sharedModel sharedMsg sharedEffect pageModel pageMsg pageEffect
    -> Model pageModel sharedModel
    -> Document (Msg pageMsg sharedMsg)
view options model =
    options.page.view model.shared model.inertia.url model.inertia.pageData model.page
        |> documentMap Page



-- EFFECTS


fromInertiaEffect :
    Options flags sharedModel sharedMsg sharedEffect pageModel pageMsg pageEffect
    -> InertiaModel
    -> Effect (Msg pageMsg sharedMsg)
    -> Cmd (Msg pageMsg sharedMsg)
fromInertiaEffect options model effect =
    case effect of
        Effect.None ->
            Cmd.none

        Effect.Batch effects ->
            Cmd.batch (List.map (fromInertiaEffect options model) effects)

        Effect.SendMsg msg ->
            Task.succeed msg
                |> Task.perform identity

        Effect.Http req ->
            onHttp model req

        Effect.PushUrl url ->
            Nav.pushUrl model.key url

        Effect.ReplaceUrl url ->
            Nav.replaceUrl model.key url

        Effect.Back int ->
            Nav.back model.key int

        Effect.Forward int ->
            Nav.forward model.key int

        Effect.Load url ->
            Nav.load url

        Effect.Reload ->
            Nav.reload

        Effect.ReloadAndSkipCache ->
            Nav.reloadAndSkipCache


onHttp : InertiaModel -> Inertia.HttpRequest.Request (Msg pageMsg sharedMsg) -> Cmd (Msg pageMsg sharedMsg)
onHttp ({ url } as model) req =
    let
        toHttpMsg : Result Http.Error (PageData Json.Decode.Value) -> Msg pageMsg sharedMsg
        toHttpMsg result =
            case result of
                Ok newPageData ->
                    if model.pageData.component == newPageData.component then
                        case Json.Decode.decodeValue req.decoder newPageData.props of
                            Ok msg ->
                                PropsChanged newPageData msg |> Inertia

                            Err jsonDecodeError ->
                                req.onFailure (Http.BadBody (Json.Decode.errorToString jsonDecodeError))

                    else
                        case fromAbsoluteUrl newPageData.url url of
                            Just newUrl ->
                                UrlRequested (Http newPageData) (Browser.Internal newUrl)
                                    |> Inertia

                            Nothing ->
                                UrlRequested (Http newPageData) (Browser.External newPageData.url)
                                    |> Inertia

                Err httpError ->
                    req.onFailure httpError

        decoder : Json.Decode.Decoder (PageData Json.Decode.Value)
        decoder =
            Inertia.PageData.decoder Json.Decode.value
    in
    Http.request
        { method = req.method
        , url = req.url
        , headers =
            [ Http.header "Accept" "text/html, application/xhtml+xml"
            , Http.header "X-Requested-With" "XMLHttpRequest"
            , Http.header "X-Inertia" "true"
            , Http.header "X-XSRF-TOKEN" model.xsrfToken
            , Http.header "X-Inertia-Version" model.pageData.version
            ]
                ++ req.headers
        , body = req.body
        , timeout = req.timeout
        , tracker = req.tracker
        , expect = Http.expectJson toHttpMsg decoder
        }



-- HELPERS


documentMap : (a -> b) -> Document a -> Document b
documentMap fn doc =
    { title = doc.title
    , body = List.map (Html.map fn) doc.body
    }


fromAbsoluteUrl : String -> Url -> Maybe Url
fromAbsoluteUrl absoluteUrl url =
    let
        baseUrl : String
        baseUrl =
            Url.toString { url | fragment = Nothing, query = Nothing, path = "" }
    in
    Url.fromString (baseUrl ++ absoluteUrl)


type alias Options flags sharedModel sharedMsg sharedEffect pageModel pageMsg pageEffect =
    { shared :
        { init : Result Json.Decode.Error flags -> Url -> ( sharedModel, sharedEffect )
        , update : Url -> sharedMsg -> sharedModel -> ( sharedModel, sharedEffect )
        , subscriptions : Url -> sharedModel -> Sub sharedMsg
        , onNavigationError : { url : Url, error : Http.Error } -> sharedMsg
        , effectToCmd :
            { fromInertiaEffect : Effect (Msg pageMsg sharedMsg) -> Cmd (Msg pageMsg sharedMsg)
            , fromSharedMsg : sharedMsg -> Msg pageMsg sharedMsg
            , shared : sharedModel
            , url : Url
            }
            -> (sharedMsg -> Msg pageMsg sharedMsg)
            -> sharedEffect
            -> Cmd (Msg pageMsg sharedMsg)
        }
    , page :
        { init : sharedModel -> Url -> PageData Json.Decode.Value -> ( pageModel, pageEffect )
        , update : sharedModel -> Url -> PageData Json.Decode.Value -> pageMsg -> pageModel -> ( pageModel, pageEffect )
        , subscriptions : sharedModel -> Url -> PageData Json.Decode.Value -> pageModel -> Sub pageMsg
        , view : sharedModel -> Url -> PageData Json.Decode.Value -> pageModel -> Browser.Document pageMsg
        , onPropsChanged : sharedModel -> Url -> PageData Json.Decode.Value -> pageModel -> ( pageModel, pageEffect )
        , effectToCmd :
            { fromInertiaEffect : Effect (Msg pageMsg sharedMsg) -> Cmd (Msg pageMsg sharedMsg)
            , fromSharedMsg : sharedMsg -> Msg pageMsg sharedMsg
            , shared : sharedModel
            , url : Url
            }
            -> (pageMsg -> Msg pageMsg sharedMsg)
            -> pageEffect
            -> Cmd (Msg pageMsg sharedMsg)
        }
    , interop :
        { decoder : Json.Decode.Decoder flags
        , onRefreshXsrfToken : () -> Cmd (Msg pageMsg sharedMsg)
        , onXsrfTokenRefreshed : (String -> Msg pageMsg sharedMsg) -> Sub (Msg pageMsg sharedMsg)
        }
    }
