module Main exposing (..)

import Html
import Color
import Date
import Element exposing (..)
import Element.Attributes exposing (..)
import Html.Events exposing (..)
import Html.Attributes
import Http
import Json.Encode as Encode
import Json.Decode as Decode
import Json.Decode.Pipeline as Pipeline exposing (decode, required, custom, hardcoded)
import Style exposing (..)
import Style.Font as Font
import Style.Color as Color
import Navigation
import UrlParser exposing (Parser, (</>), s, int, string, oneOf, parseHash)
import Date.Extra as Date


-- import Html.Attributes exposing (..)


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
    | Footer
    | Logo
    | NavOption
    | TagStyle
    | ButtonStyle


stylesheet : StyleSheet Styles variation
stylesheet =
    Style.stylesheet
        [ style None []
        , style Main
            [ Font.typeface [ "Overpass", "monospace" ]
            , Font.lineHeight 2
            ]
        , style PostTitle
            [ Font.size 32
            , Font.weight 700
            ]
        , style Logo
            [ Font.size 26
            , Font.weight 600
            , Color.text (Color.rgb 255 131 0)
            , Color.decoration (Color.rgb 255 131 0)
            ]
        , style NavOption
            [ Font.size 26
            , Font.weight 600
            ]
        , style TagStyle
            [ Color.text (Color.rgb 120 120 120)
            , Color.background (Color.rgb 242 242 242)
            ]
        , style ButtonStyle
            [ Font.typeface [ "Overpass", "monospace" ]
            ]
        , style Footer []
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


type alias Model =
    { posts : List Post
    , currentRoute : Maybe Route
    }


init : Navigation.Location -> ( Model, Cmd Msg )
init location =
    ( { posts = []
      , currentRoute = parseHash route location
      }
    , getPosts
    )



-- UPDATE


type Msg
    = LoadPosts (Result Http.Error (List Post))
    | UrlChange Navigation.Location


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        LoadPosts (Ok posts) ->
            ( { model | posts = posts }, Cmd.none )

        LoadPosts (Err _) ->
            ( model, Cmd.none )

        UrlChange location ->
            ( { model | currentRoute = parseHash route location }
            , Cmd.none
            )



-- ROUTING


type Route
    = BlogRoute
    | PostRoute String
    | AboutRoute


route : Parser (Route -> a) a
route =
    oneOf
        [ UrlParser.map PostRoute (s "blog" </> string)
        , UrlParser.map AboutRoute (s "about")
        ]



-- VIEW


view : Model -> Html.Html Msg
view model =
    column None
        []
        [ column Main
            [ center, width (px 800) ]
            [ viewHeader
            , column None
                [ spacing 100 ]
                (viewContent model)
            , viewFooter
            ]
        ]
        |> Element.root stylesheet


viewContent : Model -> List (Element Styles variation msg)
viewContent model =
    case model.currentRoute of
        Just BlogRoute ->
            viewPostsList model.posts

        Just (PostRoute slug) ->
            let
                post =
                    List.filter (\post -> post.slug == slug) model.posts |> List.head
            in
                [ viewPost post ]

        Just AboutRoute ->
            [ viewAbout ]

        Nothing ->
            viewPostsList model.posts


viewPost : Maybe Post -> Element Styles variation msg
viewPost post =
    case post of
        Just post ->
            column None
                [ spacing 5 ]
                [ viewPostMeta post
                , paragraph PostTitle [] [ text post.title ]
                , el None
                    [ width (px 800) ]
                    (viewPostBody post.body |> html)
                , viewTags post.tags
                ]

        Nothing ->
            column None
                [ spacing 10 ]
                [ paragraph PostTitle [] [ text "Nothing found" ] ]


viewPostStatus : Bool -> Element Styles variation message
viewPostStatus isPublished =
    let
        status =
            if isPublished then
                "Published"
            else
                "Draft"
    in
        el None [] (text ("[" ++ status ++ "]"))


viewPostMeta : Post -> Element Styles variation message
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
            [ el ButtonStyle [] (text "edit") |> button
            , el ButtonStyle [] (text "delete") |> button
            ]
        ]


viewPostsList : List Post -> List (Element Styles variation msg)
viewPostsList posts =
    (List.map
        (\post ->
            column None
                [ spacing 5 ]
                [ viewPostMeta post
                , paragraph PostTitle [] [ text post.title |> link ("#/blog/" ++ post.slug) ]
                , paragraph None [] [ text post.description ]
                , viewTags post.tags
                ]
        )
        posts
    )


viewTag : Tag -> Element Styles variation msg
viewTag tag =
    el TagStyle [ paddingLeft 10, paddingRight 10 ] (text tag.name)


viewTags : List Tag -> Element Styles variation msg
viewTags tags =
    row None [ spacing 10 ] (List.map viewTag tags)


{-| Renders raw HTML of a prerendered Markdown
-}
viewPostBody : String -> Html.Html msg
viewPostBody body =
    Html.div [ (Html.Attributes.property "innerHTML" (Encode.string body)) ] []


viewAbout : Element Styles variation msg
viewAbout =
    column None
        [ spacing 10 ]
        [ paragraph PostTitle [] [ text "Hello" ]
        ]


viewHeader : Element Styles variation msg
viewHeader =
    el None [ justify ] <|
        row None
            [ paddingTop 80, paddingBottom 80, spacing 80 ]
            [ el Logo [] (text "igor kuzmenko" |> link "#")
            , row None
                [ spacing 40 ]
                [ el NavOption [] (text "blog" |> link "#")
                , el NavOption [] (text "projects" |> link "#/projects")
                , el NavOption [] (text "about" |> link "#/about")
                ]
            , el NavOption [] (text "rss" |> link "http://feeds.feedburner.com/kuzzmi")
            ]


viewFooter : Element Styles variation msg
viewFooter =
    el None [] <|
        row Footer
            [ paddingTop 80, paddingBottom 80 ]
            [ paragraph None
                []
                [ text "Built with ♥ by "
                , text "@kuzzmi" |> link "https://twitter.com/kuzzmi"
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
