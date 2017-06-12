port module Main exposing (..)

import Html
import Color
import Element exposing (..)
import Element.Events exposing (..)
import Element.Attributes exposing (..)
import Html.Attributes
import Http
import Json.Encode as Encode
import Json.Decode as Decode
import Json.Decode.Pipeline as Pipeline exposing (decode, required)
import Style exposing (..)
import Style.Font as Font
import Style.Color as Color
import Navigation
import UrlParser exposing (Parser, (</>), s, int, string, oneOf, parsePath)
import Date
import Date.Extra as Date
import MD5
import Dom.Scroll
import Task
import Debug


{-| This is used to update page identificator of the page for disqus
-}
port setDisqusIdentifier : Slug -> Cmd msg


main =
    Navigation.program UrlChange
        { init = init
        , view = view
        , update = update
        , subscriptions = subscriptions
        }


type Styles
    = None
    | Main
    | PostTitle
    | Logo
    | NavOption
    | TagStyle
    | ButtonStyle
    | Footer
    | FooterLogo
    | FooterHeart


type Variations
    = Active


darkGrey : Color.Color
darkGrey =
    Color.rgb 50 50 50


orange : Color.Color
orange =
    Color.rgb 255 131 0


stylesheet : StyleSheet Styles Variations
stylesheet =
    Style.stylesheet
        [ style None []
        , style Main
            [ Font.typeface [ "Overpass", "monospace" ]
            , Font.lineHeight 2
            , Color.text darkGrey
            ]
        , style PostTitle
            [ Font.size 32
            , Font.weight 700
            , Color.text darkGrey
            , hover
                [ Font.underline
                ]
            ]
        , style Logo
            [ Font.size 26
            , Font.weight 600
            , Color.text orange
            , hover
                [ Font.underline
                ]
            ]
        , style NavOption
            [ Font.size 26
            , Font.weight 600
            , Color.text darkGrey
            , hover
                [ Font.underline
                ]
            , variation Active
                [ Color.text Color.white
                , Color.background darkGrey
                ]
            ]
        , style TagStyle
            [ Color.text (Color.rgb 120 120 120)
            , Color.background (Color.rgb 242 242 242)
            ]
        , style ButtonStyle
            [ Color.text darkGrey
            , Color.background (Color.rgb 242 242 242)
            , hover
                [ Color.text orange
                ]
            ]
        , style Footer []
        , style FooterHeart
            [ Color.text (Color.rgb 255 0 0)
            ]
        , style FooterLogo
            [ Color.text orange
            , hover
                [ Font.underline
                ]
            ]
        ]



-- MODEL


type alias Post =
    { title : String
    , body : String
    , dateCreated : Date.Date
    , isPublished : Bool
    , slug : String
    , description : String
    , tags : List Tag
    }


type alias Tag =
    { name : String
    }


type alias Slug =
    String


type alias Model =
    { posts : List Post
    , currentRoute : Maybe Route
    }


init : Navigation.Location -> ( Model, Cmd Msg )
init location =
    ( { posts = []
      , currentRoute = parsePath routeParser location
      }
    , getPosts
    )



-- UPDATE


type Msg
    = LoadPosts (Result Http.Error (List Post))
    | UrlChange Navigation.Location
    | ChangeRoute Route
    | DoNothing String


scrollToTopCmd : Cmd Msg
scrollToTopCmd =
    Dom.Scroll.toTop "body"
        |> Task.attempt (always (DoNothing ""))


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case Debug.log "message" msg of
        LoadPosts (Ok posts) ->
            ( { model | posts = posts }, Cmd.none )

        LoadPosts (Err _) ->
            ( model, Cmd.none )

        UrlChange location ->
            ( { model | currentRoute = parsePath routeParser location }
            , Cmd.batch [ setDisqusIdentifier "test", scrollToTopCmd ]
            )

        ChangeRoute route ->
            ( model
            , Cmd.batch [ scrollToTopCmd, routeToPath route |> Navigation.newUrl ]
            )

        DoNothing _ ->
            ( model, Cmd.none )



-- ROUTING


type Route
    = BlogRoute
    | PostRoute Slug
    | PostEditRoute Slug
    | AboutRoute


routeParser : Parser (Route -> a) a
routeParser =
    oneOf
        [ UrlParser.map BlogRoute (s "blog")
        , UrlParser.map PostRoute (s "blog" </> string)
        , UrlParser.map PostEditRoute (s "blog" </> string </> s "edit")
        , UrlParser.map AboutRoute (s "about")
        ]


routeToPath : Route -> String
routeToPath route =
    case route of
        BlogRoute ->
            "/blog"

        PostRoute slug ->
            "/blog/" ++ slug

        PostEditRoute slug ->
            "/blog/" ++ slug ++ "/edit"

        AboutRoute ->
            "/about"


isRouteActive : Maybe Route -> Route -> Bool
isRouteActive route parentRoute =
    case ( route, parentRoute ) of
        ( Nothing, BlogRoute ) ->
            True

        ( Just BlogRoute, BlogRoute ) ->
            True

        ( Just (PostRoute _), PostRoute _ ) ->
            True

        ( Just (PostRoute _), BlogRoute ) ->
            True

        ( Just (PostEditRoute _), PostRoute _ ) ->
            True

        ( Just (PostEditRoute _), BlogRoute ) ->
            True

        ( Just AboutRoute, AboutRoute ) ->
            True

        ( _, _ ) ->
            False



-- MAIN VIEW


view : Model -> Html.Html Msg
view model =
    column None
        []
        [ column Main
            [ center, width (px 800) ]
            [ viewHeader model.currentRoute
            , column None
                [ spacing 100 ]
                (viewContent model)
            , viewFooter
            ]
        ]
        |> Element.root stylesheet


getPostBySlug : String -> List Post -> Maybe Post
getPostBySlug slug posts =
    List.filter (\post -> post.slug == slug) posts |> List.head


viewContent : Model -> List (Element Styles Variations Msg)
viewContent model =
    case model.currentRoute of
        Just BlogRoute ->
            viewPostsList model.posts

        Just (PostRoute slug) ->
            [ getPostBySlug slug model.posts |> viewPost ]

        Just (PostEditRoute slug) ->
            [ getPostBySlug slug model.posts |> viewPost ]

        Just AboutRoute ->
            [ viewAbout ]

        Nothing ->
            viewPostsList model.posts



-- POST VIEWS


viewPost : Maybe Post -> Element Styles Variations Msg
viewPost post =
    case post of
        Just post ->
            column None
                [ spacing 5 ]
                [ viewPostMeta post
                , paragraph PostTitle [] [ text post.title ]
                , el None
                    [ width (px 800), class "post-body" ]
                    (viewPostBody post.body |> html)
                , viewTags post.tags
                ]
                |> article

        Nothing ->
            column None
                [ spacing 10 ]
                [ paragraph PostTitle [] [ text "Nothing found" ] ]


viewPostStatus : Bool -> Element Styles Variations Msg
viewPostStatus isPublished =
    let
        status =
            if isPublished then
                "Published"
            else
                "Draft"
    in
        el None [] (text ("[" ++ status ++ "]"))


viewLink style attributes label route =
    el style ((onClick (ChangeRoute route)) :: attributes) (text label) |> node "a"


viewPostMeta : Post -> Element Styles Variations Msg
viewPostMeta post =
    row None
        [ justify ]
        [ row None
            [ spacing 10 ]
            [ viewPostStatus post.isPublished
            , el None [] (Date.toFormattedString "MMMM ddd, y" post.dateCreated |> text)
            ]
        , row None
            [ spacing 10 ]
            [ viewLink ButtonStyle [ paddingXY 10 0 ] "edit" (PostEditRoute post.slug)
            , viewLink ButtonStyle [ paddingXY 10 0 ] "delete" (PostEditRoute post.slug)
            ]
        ]


viewPostsListItem : Post -> Element Styles Variations Msg
viewPostsListItem post =
    column None
        [ spacing 5 ]
        [ viewPostMeta post
        , el PostTitle [ onClick (PostRoute post.slug |> ChangeRoute) ] (text post.title)
        , paragraph None [] [ text post.description ]
        , viewTags post.tags
        ]


viewPostsList : List Post -> List (Element Styles Variations Msg)
viewPostsList posts =
    List.map viewPostsListItem posts


viewTag : Tag -> Element Styles Variations Msg
viewTag tag =
    el TagStyle [ paddingXY 10 0 ] (text tag.name)


viewTags : List Tag -> Element Styles Variations Msg
viewTags tags =
    row None [ spacing 10 ] (List.map viewTag tags)


{-| Renders raw HTML of a prerendered Markdown
-}
viewPostBody : String -> Html.Html msg
viewPostBody body =
    Html.div [ (Html.Attributes.property "innerHTML" (Encode.string body)) ] []



-- ABOUT ROUTE


viewGravatar : String -> Element Styles Variations msg
viewGravatar email =
    let
        gravatarUrl =
            "https://www.gravatar.com/avatar/"

        gravatarHash =
            MD5.hex email

        gravatarOptions =
            "?s=200"

        imageUrl =
            gravatarUrl ++ gravatarHash ++ gravatarOptions
    in
        image imageUrl None [] (text "My Photo")


viewAbout : Element Styles Variations msg
viewAbout =
    column None
        [ spacing 10 ]
        [ viewGravatar "kuzzmi@gmail.com"
        , el None [] (text "Hello, my name is Igor. I love my wife, JavaScript, and Vim.")
        ]


viewHeader : Maybe Route -> Element Styles Variations Msg
viewHeader currentRoute =
    let
        isActive route =
            isRouteActive currentRoute route

        navLink label route =
            viewLink NavOption [ vary Active (isActive route), paddingXY 15 0 ] label route
    in
        el None [ justify ] <|
            row None
                [ paddingTop 80, paddingBottom 80, spacing 40 ]
                [ el Logo [ onClick (ChangeRoute BlogRoute) ] (text "igor kuzmenko_")
                , row None
                    [ spacing 40 ]
                    [ navLink "blog" BlogRoute
                    , navLink "about" AboutRoute
                    ]
                , el NavOption [] (text "rss") |> link "http://feeds.feedburner.com/kuzzmi"
                ]


viewFooter : Element Styles variation msg
viewFooter =
    el None [] <|
        row Footer
            [ paddingTop 80, paddingBottom 80 ]
            [ row None
                [ spacing 10 ]
                [ el None [] (text "Built with")
                , el FooterHeart [] (text "♥")
                , el None [] (text "by")
                , el FooterLogo [] (text "@kuzzmi") |> link "https://twitter.com/kuzzmi"
                ]
            ]



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.none



-- HTTP


makeApiCall endpoint message decoder =
    let
        url =
            "http://localhost:3000/api/"

        fullUrl =
            url ++ endpoint
    in
        Http.send message (Http.get fullUrl decoder)


getPosts : Cmd Msg
getPosts =
    makeApiCall "posts" LoadPosts postsDecoder



-- DECODERS


dateDecoder : Decode.Decoder Date.Date
dateDecoder =
    Decode.string
        |> Decode.andThen
            (\str ->
                case Date.fromString str of
                    Err err ->
                        Decode.fail err

                    Ok date ->
                        Decode.succeed date
            )


tagDecoder : Decode.Decoder Tag
tagDecoder =
    decode Tag
        |> Pipeline.required "name" Decode.string


basePostDecoder : Decode.Decoder Post
basePostDecoder =
    decode Post
        |> Pipeline.required "title" Decode.string
        |> Pipeline.required "body" Decode.string
        |> Pipeline.required "dateCreated" dateDecoder
        |> Pipeline.required "isPublished" Decode.bool
        |> Pipeline.required "slug" Decode.string
        |> Pipeline.required "description" (Decode.map (Maybe.withDefault "") (Decode.nullable Decode.string))
        |> Pipeline.required "tags" (Decode.list tagDecoder)


postsDecoder : Decode.Decoder (List Post)
postsDecoder =
    Decode.field "posts" (Decode.list basePostDecoder)
