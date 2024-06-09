module Inertia exposing
    ( Program
    , Model, Msg
    , program
    , PageObject
    )

{-| This module allows you to create Elm applications that work with Inertia.js.


# **Getting started**


### **Recommended: Using the starter kit**

For convenience, the [@ryan-haskell/elm-inertia-starter](https://github.com/ryan-haskell/elm-inertia-starter)
template has everything you need for dropping Elm into an Inertia.js supported project.

It follows the exact documentation below, to save you the manual work.


### **Advanced: Creating a project from scratch**

The rest of documentation will walk you through using this package without a starter kit. It assumes you have the following project structure:

    - your-project/
        - elm.json
        - src/
            - Main.elm
            - Page.elm
            - Shared.elm
            - Effect.elm
            - Interop.elm

**Note:** The type variables make these signatures look scary, but the documentation
below will show you how easy this module is to work with in practice!


# **Creating programs**

@docs Program
@docs Model, Msg
@docs program


# **Inertia Page Object**

@docs PageObject

-}

import Browser exposing (Document, UrlRequest)
import Browser.Dom
import Browser.Events
import Browser.Navigation as Nav exposing (Key)
import Html exposing (Html)
import Http
import Inertia.Internals.Effect as Effect exposing (Effect)
import Inertia.Internals.Request exposing (Request)
import Json.Decode
import Json.Encode
import Process
import Task
import Url exposing (Url)



-- CREATING PROGRAMS


{-| Exposed to allow you to make type annotations for your `main` function.
-}
type alias Program model msg =
    Platform.Program Flags model msg


{-| Exposed to allow you to make type annotations in your `Main` module.

    type alias Model =
        Inertia.Model Pages.Model Shared.Model

-}
type Model pageModel sharedModel
    = Model (ModelInternals pageModel sharedModel)


{-| Exposed to allow you to make type annotations in your `Main` module.

    type alias Msg =
        Inertia.Msg Pages.Msg Shared.Msg

-}
type Msg pageMsg sharedMsg
    = Page pageMsg
    | Shared sharedMsg
    | Inertia (InertiaMsg (Msg pageMsg sharedMsg))


{-| Create a new program from four modules in your project.

    import Effect
    import Inertia
    import Interop
    import Page
    import Shared

    type alias Model =
        Inertia.Model Page.Model Shared.Model

    type alias Msg =
        Inertia.Msg Page.Msg Shared.Msg

    main : Inertia.Program Model Msg
    main =
        Inertia.program
            { page =
                { init = Page.init
                , update = Page.update
                , view = Page.view
                , subscriptions = Page.subscriptions
                , onPropsChanged = Page.onPropsChanged
                }
            , shared =
                { init = Shared.init
                , update = Shared.update
                , subscriptions = Shared.subscriptions
                , onNavigationError = Shared.onNavigationError
                }
            , inertia =
                { decoder = Interop.decoder
                , onXsrfTokenRefreshed = Interop.onXsrfTokenRefreshed
                , onRefreshXsrfToken = Interop.onRefreshXsrfToken
                }
            , fromCustomEffectToCmd = fromCustomEffectToCmd
            }

    fromCustomEffectToCmd :
        { shared : Shared.Model
        , url : Url
        , fromSharedMsg : Shared.Msg -> msg
        }
        -> Effect.CustomEffect
        -> Cmd msg
    fromCustomEffectToCmd context customEffect =
        Effect.switch customEffect
            { onDoNothing = Cmd.none
            }

-}
program :
    { page :
        { init : sharedModel -> Url -> PageObject Json.Decode.Value -> ( pageModel, Effect customPage pageMsg )
        , update : sharedModel -> Url -> PageObject Json.Decode.Value -> pageMsg -> pageModel -> ( pageModel, Effect customPage pageMsg )
        , subscriptions : sharedModel -> Url -> PageObject Json.Decode.Value -> pageModel -> Sub pageMsg
        , view : sharedModel -> Url -> PageObject Json.Decode.Value -> pageModel -> Browser.Document pageMsg
        , onPropsChanged : sharedModel -> Url -> PageObject Json.Decode.Value -> pageModel -> ( pageModel, Effect customPage pageMsg )
        }
    , shared :
        { init : Result Json.Decode.Error flags -> Url -> ( sharedModel, Effect customShared sharedMsg )
        , update : Url -> sharedMsg -> sharedModel -> ( sharedModel, Effect customShared sharedMsg )
        , subscriptions : Url -> sharedModel -> Sub sharedMsg
        , onNavigationError : { url : Url, error : Http.Error } -> sharedMsg
        }
    , interop :
        { decoder : Json.Decode.Decoder flags
        , onRefreshXsrfToken : () -> Cmd (Msg pageMsg sharedMsg)
        , onXsrfTokenRefreshed : (String -> Msg pageMsg sharedMsg) -> Sub (Msg pageMsg sharedMsg)
        }
    , effect :
        { fromShared : (sharedMsg -> Msg pageMsg sharedMsg) -> customShared -> customEffect
        , fromPage : (pageMsg -> Msg pageMsg sharedMsg) -> customPage -> customEffect
        , fromCustomEffectToCmd :
            { shared : sharedModel
            , url : Url
            , fromSharedMsg : sharedMsg -> Msg pageMsg sharedMsg
            }
            -> customEffect
            -> Cmd (Msg pageMsg sharedMsg)
        }
    }
    -> Program (Model pageModel sharedModel) (Msg pageMsg sharedMsg)
program options =
    Browser.application
        { init = init options
        , update = update options
        , view = view options
        , subscriptions = subscriptions options
        , onUrlChange = UrlChanged >> Inertia
        , onUrlRequest = UrlRequested LinkClicked >> Inertia
        }



-- FLAGS


type alias Flags =
    Json.Decode.Value


type alias AppFlags flags =
    { inertia : InertiaFlags
    , user : flags
    }


type alias InertiaFlags =
    { xsrfToken : String
    , pageObject : PageObject Json.Decode.Value
    }


interiaFlagsDecoder : Json.Decode.Decoder InertiaFlags
interiaFlagsDecoder =
    Json.Decode.map2 InertiaFlags
        (Json.Decode.field "xsrfToken" Json.Decode.string)
        (Json.Decode.field "pageObject" (pageObjectDecoder Json.Decode.value))


inertiaFlagsFallback : InertiaFlags
inertiaFlagsFallback =
    -- Only occurs if application is not initialized with "elm-inertia.js"
    { xsrfToken = "???"
    , pageObject =
        { component = "???"
        , props = Json.Encode.null
        , url = "???"
        , version = "???"
        }
    }


strictDecodeFlags :
    Options flags sharedModel sharedMsg pageModel pageMsg customEffect customPage customShared
    -> Json.Decode.Value
    -> Result Json.Decode.Error (AppFlags flags)
strictDecodeFlags options json =
    Json.Decode.decodeValue
        (Json.Decode.map2 AppFlags
            (Json.Decode.field "inertia" interiaFlagsDecoder)
            (Json.Decode.field "user" options.interop.decoder)
        )
        json



-- MODEL


type alias ModelInternals pageModel sharedModel =
    { inertia : InertiaModel
    , page : pageModel
    , shared : sharedModel
    }


type alias InertiaModel =
    { url : Url
    , key : Key
    , pageObject : PageObject Json.Decode.Value
    , xsrfToken : String
    , urlRequestSource : UrlRequestSource
    }


init :
    Options flags sharedModel sharedMsg pageModel pageMsg customEffect customPage customShared
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
            options.page.init shared url inertiaFlags.pageObject

        inertia : InertiaModel
        inertia =
            { url = url
            , key = key
            , pageObject = inertiaFlags.pageObject
            , xsrfToken = inertiaFlags.xsrfToken
            , urlRequestSource = AppLoaded
            }

        model : ModelInternals pageModel sharedModel
        model =
            { inertia = inertia
            , page = page
            , shared = shared
            }
    in
    ( Model model
    , Cmd.batch
        [ sharedEffect
            |> Effect.map (options.effect.fromShared Shared) Shared
            |> fromInertiaEffect { shared = model.shared, fromSharedMsg = Shared, url = model.inertia.url }
                options
                model.inertia
        , pageEffect
            |> Effect.map (options.effect.fromPage Page) Page
            |> fromInertiaEffect { shared = model.shared, fromSharedMsg = Shared, url = model.inertia.url }
                options
                model.inertia
        ]
    )



-- UPDATE


type InertiaMsg msg
    = UrlChanged Url
    | UrlRequested UrlRequestSource UrlRequest
    | InertiaPageObjectResponded Url (Result Http.Error (PageObject Json.Decode.Value))
    | XsrfTokenRefreshed String
    | ScrollFinished
    | PropsChanged (PageObject Json.Decode.Value) msg


type UrlRequestSource
    = AppLoaded
    | LinkClicked
    | Http (PageObject Json.Decode.Value)


update :
    Options flags sharedModel sharedMsg pageModel pageMsg customEffect customPage customShared
    -> Msg pageMsg sharedMsg
    -> Model pageModel sharedModel
    ->
        ( Model pageModel sharedModel
        , Cmd (Msg pageMsg sharedMsg)
        )
update options msg (Model model) =
    case msg of
        Page pageMsg ->
            let
                ( pageModel, pageEffect ) =
                    options.page.update model.shared model.inertia.url model.inertia.pageObject pageMsg model.page
            in
            ( Model { model | page = pageModel }
            , pageEffect
                |> Effect.map (options.effect.fromPage Page) Page
                |> fromInertiaEffect { shared = model.shared, fromSharedMsg = Shared, url = model.inertia.url }
                    options
                    model.inertia
            )

        Shared sharedMsg ->
            let
                ( sharedModel, sharedEffect ) =
                    options.shared.update model.inertia.url sharedMsg model.shared
            in
            ( Model { model | shared = sharedModel }
            , sharedEffect
                |> Effect.map (options.effect.fromShared Shared) Shared
                |> fromInertiaEffect { shared = model.shared, fromSharedMsg = Shared, url = model.inertia.url }
                    options
                    model.inertia
            )

        Inertia inertiaMsg ->
            let
                ( inertiaModel, inertiaCmd, trigger ) =
                    inertiaUpdate options inertiaMsg model.inertia
            in
            case trigger of
                TriggerNone ->
                    ( Model { model | inertia = inertiaModel }
                    , inertiaCmd
                    )

                TriggerPagePropsChanged pageObject ->
                    let
                        ( page, pageEffect ) =
                            options.page.onPropsChanged model.shared model.inertia.url pageObject model.page
                    in
                    ( Model { model | inertia = inertiaModel, page = page }
                    , Cmd.batch
                        [ inertiaCmd
                        , pageEffect
                            |> Effect.map (options.effect.fromPage Page) Page
                            |> fromInertiaEffect { shared = model.shared, fromSharedMsg = Shared, url = model.inertia.url }
                                options
                                model.inertia
                        ]
                    )

                TriggerPageInit pageObject ->
                    let
                        ( page, pageEffect ) =
                            options.page.init model.shared model.inertia.url pageObject
                    in
                    ( Model { model | inertia = inertiaModel, page = page }
                    , Cmd.batch
                        [ inertiaCmd
                        , pageEffect
                            |> Effect.map (options.effect.fromPage Page) Page
                            |> fromInertiaEffect { shared = model.shared, fromSharedMsg = Shared, url = model.inertia.url }
                                options
                                model.inertia
                        ]
                    )


type Trigger
    = TriggerNone
    | TriggerPagePropsChanged (PageObject Json.Decode.Value)
    | TriggerPageInit (PageObject Json.Decode.Value)


inertiaUpdate :
    Options flags sharedModel sharedMsg pageModel pageMsg customEffect customPage customShared
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
                                , Http.header "X-Inertia-Version" model.pageObject.version
                                ]
                            , body = Http.emptyBody
                            , timeout = Nothing
                            , tracker = Nothing
                            , expect =
                                Http.expectJson
                                    (InertiaPageObjectResponded url >> Inertia)
                                    (pageObjectDecoder Json.Decode.value)
                            }
                in
                ( { model | url = url }
                , case model.urlRequestSource of
                    AppLoaded ->
                        performInertiaGetRequest

                    LinkClicked ->
                        performInertiaGetRequest

                    Http newPageObject ->
                        if newPageObject.component == model.pageObject.component then
                            performInertiaGetRequest

                        else
                            Task.succeed (Ok newPageObject)
                                |> Task.perform (InertiaPageObjectResponded url >> Inertia)
                , TriggerNone
                )

        PropsChanged pageObject innerMsg ->
            ( { model | pageObject = pageObject }
            , Task.succeed innerMsg |> Task.perform identity
            , TriggerPagePropsChanged pageObject
            )

        InertiaPageObjectResponded url (Ok pageObject) ->
            ( { model | pageObject = pageObject }
            , Cmd.batch
                [ options.interop.onRefreshXsrfToken ()
                , Browser.Dom.setViewportOf "scroll-region" 0 0
                    |> Task.attempt (\_ -> Inertia ScrollFinished)
                ]
            , if model.pageObject.component == pageObject.component then
                TriggerPagePropsChanged pageObject

              else
                TriggerPageInit pageObject
            )

        InertiaPageObjectResponded url (Err httpError) ->
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
    Options flags sharedModel sharedMsg pageModel pageMsg customEffect customPage customShared
    -> Model pageModel sharedModel
    -> Sub (Msg pageMsg sharedMsg)
subscriptions options (Model model) =
    Sub.batch
        [ options.page.subscriptions model.shared model.inertia.url model.inertia.pageObject model.page
            |> Sub.map Page
        , options.shared.subscriptions model.inertia.url model.shared
            |> Sub.map Shared
        , options.interop.onXsrfTokenRefreshed (XsrfTokenRefreshed >> Inertia)
        ]



-- VIEW


view :
    Options flags sharedModel sharedMsg pageModel pageMsg customEffect customPage customShared
    -> Model pageModel sharedModel
    -> Document (Msg pageMsg sharedMsg)
view options (Model model) =
    options.page.view model.shared model.inertia.url model.inertia.pageObject model.page
        |> documentMap Page



-- EFFECTS


fromInertiaEffect :
    { shared : sharedModel
    , url : Url
    , fromSharedMsg : sharedMsg -> Msg pageMsg sharedMsg
    }
    -> Options flags sharedModel sharedMsg pageModel pageMsg customEffect customPage customShared
    -> InertiaModel
    -> Effect customEffect (Msg pageMsg sharedMsg)
    -> Cmd (Msg pageMsg sharedMsg)
fromInertiaEffect context options model effect =
    case effect of
        Effect.None ->
            Cmd.none

        Effect.Batch effects ->
            Cmd.batch (List.map (fromInertiaEffect context options model) effects)

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

        Effect.Custom data ->
            options.effect.fromCustomEffectToCmd context data


onHttp : InertiaModel -> Request (Msg pageMsg sharedMsg) -> Cmd (Msg pageMsg sharedMsg)
onHttp ({ url } as model) req =
    let
        toHttpMsg : Result Http.Error (PageObject Json.Decode.Value) -> Msg pageMsg sharedMsg
        toHttpMsg result =
            case result of
                Ok newPageObject ->
                    if model.pageObject.component == newPageObject.component then
                        case Json.Decode.decodeValue req.decoder newPageObject.props of
                            Ok msg ->
                                PropsChanged newPageObject msg |> Inertia

                            Err jsonDecodeError ->
                                req.onFailure (Http.BadBody (Json.Decode.errorToString jsonDecodeError))

                    else
                        case fromAbsoluteUrl newPageObject.url url of
                            Just newUrl ->
                                UrlRequested (Http newPageObject) (Browser.Internal newUrl)
                                    |> Inertia

                            Nothing ->
                                UrlRequested (Http newPageObject) (Browser.External newPageObject.url)
                                    |> Inertia

                Err httpError ->
                    req.onFailure httpError

        decoder : Json.Decode.Decoder (PageObject Json.Decode.Value)
        decoder =
            pageObjectDecoder Json.Decode.value
    in
    Http.request
        { method = req.method
        , url = req.url
        , headers =
            [ Http.header "Accept" "text/html, application/xhtml+xml"
            , Http.header "X-Requested-With" "XMLHttpRequest"
            , Http.header "X-Inertia" "true"
            , Http.header "X-XSRF-TOKEN" model.xsrfToken
            , Http.header "X-Inertia-Version" model.pageObject.version
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


type alias Options flags sharedModel sharedMsg pageModel pageMsg customEffect customPage customShared =
    { page :
        { init : sharedModel -> Url -> PageObject Json.Decode.Value -> ( pageModel, Effect customPage pageMsg )
        , update : sharedModel -> Url -> PageObject Json.Decode.Value -> pageMsg -> pageModel -> ( pageModel, Effect customPage pageMsg )
        , subscriptions : sharedModel -> Url -> PageObject Json.Decode.Value -> pageModel -> Sub pageMsg
        , view : sharedModel -> Url -> PageObject Json.Decode.Value -> pageModel -> Browser.Document pageMsg
        , onPropsChanged : sharedModel -> Url -> PageObject Json.Decode.Value -> pageModel -> ( pageModel, Effect customPage pageMsg )
        }
    , shared :
        { init : Result Json.Decode.Error flags -> Url -> ( sharedModel, Effect customShared sharedMsg )
        , update : Url -> sharedMsg -> sharedModel -> ( sharedModel, Effect customShared sharedMsg )
        , subscriptions : Url -> sharedModel -> Sub sharedMsg
        , onNavigationError : { url : Url, error : Http.Error } -> sharedMsg
        }
    , interop :
        { decoder : Json.Decode.Decoder flags
        , onRefreshXsrfToken : () -> Cmd (Msg pageMsg sharedMsg)
        , onXsrfTokenRefreshed : (String -> Msg pageMsg sharedMsg) -> Sub (Msg pageMsg sharedMsg)
        }
    , effect :
        { fromShared : (sharedMsg -> Msg pageMsg sharedMsg) -> customShared -> customEffect
        , fromPage : (pageMsg -> Msg pageMsg sharedMsg) -> customPage -> customEffect
        , fromCustomEffectToCmd :
            { shared : sharedModel
            , url : Url
            , fromSharedMsg : sharedMsg -> Msg pageMsg sharedMsg
            }
            -> customEffect
            -> Cmd (Msg pageMsg sharedMsg)
        }
    }



-- PAGE OBJECT


{-| This represents [the "page object"](https://inertiajs.com/the-protocol#the-page-object) sent back with every Inertia
response. In our `Page.init` function, we use the "component" field to determine which Elm page should be rendered.

The page object includes the following four properties:

1.  `component`: The name of the JavaScript page component.
2.  `props`: The page props (data).
3.  `url`: The page URL.
4.  `version`: The current asset version.

-}
type alias PageObject props =
    { component : String
    , props : props
    , url : String
    , version : String
    }


pageObjectDecoder : Json.Decode.Decoder props -> Json.Decode.Decoder (PageObject props)
pageObjectDecoder propsDecoder =
    Json.Decode.map4 PageObject
        (Json.Decode.field "component" Json.Decode.string)
        (Json.Decode.field "props" propsDecoder)
        (Json.Decode.field "url" Json.Decode.string)
        (Json.Decode.field "version" Json.Decode.string)
