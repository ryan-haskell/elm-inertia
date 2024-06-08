module Inertia exposing
    ( Program
    , Model, Msg
    , program
    , PageModule
    , SharedModule
    , InteropModule
    , EffectModule, EffectContext
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


# **Modules**

@docs PageModule
@docs SharedModule
@docs InteropModule
@docs EffectModule, EffectContext

@docs PageObject

-}

import Browser exposing (Document, UrlRequest)
import Browser.Dom
import Browser.Events
import Browser.Navigation as Nav exposing (Key)
import Html exposing (Html)
import Http
import Inertia.Effect as Effect exposing (Effect)
import Inertia.Internals.Request exposing (Request)
import Json.Decode
import Json.Encode
import Process
import Task
import Url exposing (Url)



-- CREATING PROGRAMS


{-| Exposed to allow you to make type annotations for your `main` function.

    import Inertia
    import Page
    import Shared

    type alias Model =
        Inertia.Model Page.Model Shared.Model

    type alias Msg =
        Inertia.Msg Page.Msg Shared.Msg

    main : Inertia.Program Model Msg
    main =
        ...

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
            { page = pageModule
            , shared = sharedModule
            , inertia = inertiaModule
            , effect = effectModule
            }

    --
    -- ( We'll define those modules below! )
    --

-}
program :
    { shared : SharedModule flags sharedModel sharedMsg sharedEffect
    , page : PageModule sharedModel pageModel pageMsg pageEffect
    , effect : EffectModule sharedModel sharedMsg sharedEffect pageMsg pageEffect
    , interop : InteropModule flags pageMsg sharedMsg
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



-- MODULES


{-| The page module determines which page should be visible, and how to manage it's state.

    import Effect exposing (Effect)
    import Inertia
    import Page
    import Shared

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

-}
type alias PageModule shared model msg effect =
    { init : shared -> Url -> PageObject Json.Decode.Value -> ( model, effect )
    , update : shared -> Url -> PageObject Json.Decode.Value -> msg -> model -> ( model, effect )
    , view : shared -> Url -> PageObject Json.Decode.Value -> model -> Browser.Document msg
    , subscriptions : shared -> Url -> PageObject Json.Decode.Value -> model -> Sub msg
    , onPropsChanged : shared -> Url -> PageObject Json.Decode.Value -> model -> ( model, effect )
    }


{-| The shared module defines state available to your whole application.

    import Effect exposing (Effect)
    import Inertia
    import Interop exposing (Flags)
    import Shared

    type alias SharedModule =
        Inertia.SharedModule Interop.Flags Shared.Model Shared.Msg (Effect Shared.Msg)

    sharedModule : SharedModule
    sharedModule =
        { init = Shared.init
        , update = Shared.update
        , view = Shared.view
        , subscriptions = Shared.subscriptions
        , onNavigationError = Shared.NavigationError
        }

-}
type alias SharedModule flags model msg effect =
    { init : Result Json.Decode.Error flags -> Url -> ( model, effect )
    , update : Url -> msg -> model -> ( model, effect )
    , subscriptions : Url -> model -> Sub msg
    , onNavigationError : { url : Url, error : Http.Error } -> msg
    }


{-| The interop module allows our app to communicate with JavaScript.

    import Inertia
    import Interop
    import Page
    import Shared

    type alias InteropModule =
        Inertia.InteropModule Interop.Flags Page.Msg Shared.Msg

    interopModule : InteropModule
    interopModule =
        { decoder = Interop.decoder
        , onRefreshXsrfToken = Interop.onRefreshXsrfToken
        , onXsrfTokenRefreshed = Interop.onXsrfTokenRefreshed
        }

-}
type alias InteropModule flags pageMsg sharedMsg =
    { decoder : Json.Decode.Decoder flags
    , onRefreshXsrfToken : () -> Cmd (Msg pageMsg sharedMsg)
    , onXsrfTokenRefreshed : (String -> Msg pageMsg sharedMsg) -> Sub (Msg pageMsg sharedMsg)
    }


{-| The effect module helps your Inertia.Program understand how effects become commands.


### **Scenario 1. If you are _not_ customizing Effect**

You can use the `Inertia.Effect` module's `Effect` type directly. Your `effectModule`
will look something like this:

    -- module Main exposing (main)


    import Inertia.Effect as Effect exposing (Effect)

    type alias EffectModule =
        Inertia.EffectModule Shared.Model Shared.Msg (Effect Shared.Msg) Page.Msg (Effect Page.Msg)

    type alias EffectContext =
        Inertia.EffectContext Shared.Model Shared.Msg Page.Msg

    effectModule : EffectModule
    effectModule =
        { fromPage = fromEffectToCmd
        , fromShared = fromEffectToCmd
        }

    fromEffectToCmd :
        EffectContext
        -> (anyMsg -> Msg)
        -> Effect anyMsg
        -> Cmd Msg
    fromEffectToCmd context toMsg effect =
        effect
            |> Effect.map toMsg
            |> context.fromInertiaEffect


### **Scenario 2. If you have a custom Effect type**

Most applications will need to define a custom Effect type, that uses the `Inertia.Effect` internally, but
also supports the ability for pages to define effects specific to your app's needs.

Your `effectModule` will look something like this:

    -- module Main exposing (main)


    import Effect exposing (Effect)

    type alias EffectModule =
        Inertia.EffectModule Shared.Model Shared.Msg (Effect Shared.Msg) Page.Msg (Effect Page.Msg)

    type alias EffectContext =
        Inertia.EffectContext Shared.Model Shared.Msg Page.Msg

    effectModule : EffectModule
    effectModule =
        { fromPage = fromEffectToCmd
        , fromShared = fromEffectToCmd
        }

    fromEffectToCmd :
        EffectContext
        -> (anyMsg -> Msg)
        -> Effect anyMsg
        -> Cmd Msg
    fromEffectToCmd context toMsg effect =
        effect
            |> Effect.map toMsg
            |> performEffect context

    performEffect : EffectContext -> Effect Msg -> Cmd Msg
    performEffect context effect =
        case effect of
            Effect.None ->
                Cmd.none

            Effect.Inertia inertiaEffect ->
                context.fromInertiaEffect inertiaEffect

            ...

-}
type alias EffectModule sharedModel sharedMsg sharedEffect pageMsg pageEffect =
    { fromShared :
        EffectContext sharedModel sharedMsg pageMsg
        -> (sharedMsg -> Msg pageMsg sharedMsg)
        -> sharedEffect
        -> Cmd (Msg pageMsg sharedMsg)
    , fromPage :
        EffectContext sharedModel sharedMsg pageMsg
        -> (pageMsg -> Msg pageMsg sharedMsg)
        -> pageEffect
        -> Cmd (Msg pageMsg sharedMsg)
    }


{-| This is passed into your effect functions to allow you to access important data when
performing effects.

See the [EffectModule](#EffectModule) documentation above for complete usage.

    type alias EffectContext =
        Inertia.EffectContext Shared.Model Shared.Msg Page.Msg

-}
type alias EffectContext sharedModel sharedMsg pageMsg =
    { fromInertiaEffect : Effect (Msg pageMsg sharedMsg) -> Cmd (Msg pageMsg sharedMsg)
    , fromSharedMsg : sharedMsg -> Msg pageMsg sharedMsg
    , shared : sharedModel
    , url : Url
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
    Options flags sharedModel sharedMsg sharedEffect pageModel pageMsg pageEffect
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
        [ options.effect.fromPage
            { fromInertiaEffect = fromInertiaEffect options model.inertia
            , fromSharedMsg = Shared
            , shared = model.shared
            , url = model.inertia.url
            }
            Page
            pageEffect
        , options.effect.fromShared
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
    Options flags sharedModel sharedMsg sharedEffect pageModel pageMsg pageEffect
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
            , options.effect.fromPage
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
            ( Model { model | shared = sharedModel }
            , options.effect.fromShared
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
                        , options.effect.fromPage
                            { fromInertiaEffect = fromInertiaEffect options model.inertia
                            , fromSharedMsg = Shared
                            , shared = model.shared
                            , url = model.inertia.url
                            }
                            Page
                            pageEffect
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
                        , options.effect.fromPage
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
    | TriggerPagePropsChanged (PageObject Json.Decode.Value)
    | TriggerPageInit (PageObject Json.Decode.Value)


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
    Options flags sharedModel sharedMsg sharedEffect pageModel pageMsg pageEffect
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
    Options flags sharedModel sharedMsg sharedEffect pageModel pageMsg pageEffect
    -> Model pageModel sharedModel
    -> Document (Msg pageMsg sharedMsg)
view options (Model model) =
    options.page.view model.shared model.inertia.url model.inertia.pageObject model.page
        |> documentMap Page



-- EFFECTS


fromInertiaEffect :
    Options flags sharedModel sharedMsg sharedEffect pageModel pageMsg pageEffect
    -> InertiaModel
    -> Effect (Msg pageMsg sharedMsg)
    -> Cmd (Msg pageMsg sharedMsg)
fromInertiaEffect options model effect =
    Effect.switch effect
        { onNone = Cmd.none
        , onBatch =
            \effects ->
                Cmd.batch (List.map (fromInertiaEffect options model) effects)
        , onSendMsg =
            \msg ->
                Task.succeed msg
                    |> Task.perform identity
        , onHttp =
            \req ->
                onHttp model req
        , onPushUrl =
            \url ->
                Nav.pushUrl model.key url
        , onReplaceUrl =
            \url ->
                Nav.replaceUrl model.key url
        , onBack =
            \int ->
                Nav.back model.key int
        , onForward =
            \int ->
                Nav.forward model.key int
        , onLoad =
            \url ->
                Nav.load url
        , onReload = Nav.reload
        , onReloadAndSkipCache = Nav.reloadAndSkipCache
        }


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


type alias Options flags sharedModel sharedMsg sharedEffect pageModel pageMsg pageEffect =
    { shared :
        { init : Result Json.Decode.Error flags -> Url -> ( sharedModel, sharedEffect )
        , update : Url -> sharedMsg -> sharedModel -> ( sharedModel, sharedEffect )
        , subscriptions : Url -> sharedModel -> Sub sharedMsg
        , onNavigationError : { url : Url, error : Http.Error } -> sharedMsg
        }
    , page :
        { init : sharedModel -> Url -> PageObject Json.Decode.Value -> ( pageModel, pageEffect )
        , update : sharedModel -> Url -> PageObject Json.Decode.Value -> pageMsg -> pageModel -> ( pageModel, pageEffect )
        , subscriptions : sharedModel -> Url -> PageObject Json.Decode.Value -> pageModel -> Sub pageMsg
        , view : sharedModel -> Url -> PageObject Json.Decode.Value -> pageModel -> Browser.Document pageMsg
        , onPropsChanged : sharedModel -> Url -> PageObject Json.Decode.Value -> pageModel -> ( pageModel, pageEffect )
        }
    , effect :
        { fromShared :
            EffectContext sharedModel sharedMsg pageMsg
            -> (sharedMsg -> Msg pageMsg sharedMsg)
            -> sharedEffect
            -> Cmd (Msg pageMsg sharedMsg)
        , fromPage :
            EffectContext sharedModel sharedMsg pageMsg
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
