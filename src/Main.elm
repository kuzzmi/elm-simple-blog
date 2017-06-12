port module Main exposing (main, setDisqusIdentifier)

import Html
import Element exposing (..)
import Element.Events exposing (..)
import Element.Attributes exposing (..)
import Html.Attributes
import Http
import Json.Encode as Encode
import Json.Decode as Decode
import Json.Decode.Pipeline as Pipeline exposing (decode, required)
import Navigation
import UrlParser exposing (Parser, (</>), s, int, string, oneOf, parsePath)
import Date
import Date.Extra as Date
import Dom.Scroll
import Task
import Debug
import Styles exposing (..)
import Gravatar exposing (getGravatarUrl)


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



-- MODEL


type alias ID =
    String


type alias Post =
    { id : ID
    , title : String
    , body : String
    , markdown : String
    , dateCreated : Date.Date
    , isPublished : Bool
    , slug : String
    , description : String
    , tags : List Tag
    }


type alias Tag =
    { id : ID
    , name : String
    }


type alias Slug =
    String


type alias Model =
    { posts : List Post
    , tags : List Tag
    , currentRoute : Maybe Route
    }


init : Navigation.Location -> ( Model, Cmd Msg )
init location =
    ( { posts = []
      , tags = []
      , currentRoute = parsePath routeParser location
      }
    , Cmd.batch [ getPosts, getTags ]
    )



-- UPDATE


type Msg
    = LoadPosts (Result Http.Error (List Post))
    | LoadTags (Result Http.Error (List Tag))
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
            ( { model | posts = posts }, setDisqusIdentifier "test" )

        LoadPosts (Err _) ->
            ( model, Cmd.none )

        LoadTags (Ok tags) ->
            ( { model | tags = tags }, Cmd.none )

        LoadTags (Err _) ->
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
    = PostsListRoute
    | PostsListByTagRoute ID
    | PostViewRoute Slug
    | PostEditRoute Slug
    | AboutRoute


routeParser : Parser (Route -> a) a
routeParser =
    oneOf
        [ UrlParser.map PostsListRoute (s "blog")
        , UrlParser.map PostsListByTagRoute (s "blog" </> s "tags" </> string)
        , UrlParser.map PostViewRoute (s "blog" </> string)
        , UrlParser.map PostEditRoute (s "blog" </> string </> s "edit")
        , UrlParser.map AboutRoute (s "about")
        ]


routeToPath : Route -> String
routeToPath route =
    case route of
        PostsListRoute ->
            "/blog"

        PostsListByTagRoute id ->
            "/blog/tags/" ++ id

        PostViewRoute slug ->
            "/blog/" ++ slug

        PostEditRoute slug ->
            "/blog/" ++ slug ++ "/edit"

        AboutRoute ->
            "/about"


isRouteActive : Maybe Route -> Route -> Bool
isRouteActive route parentRoute =
    case ( route, parentRoute ) of
        ( Nothing, PostsListRoute ) ->
            True

        ( Just PostsListRoute, PostsListRoute ) ->
            True

        ( Just (PostsListByTagRoute _), PostsListRoute ) ->
            True

        ( Just (PostViewRoute _), PostViewRoute _ ) ->
            True

        ( Just (PostViewRoute _), PostsListRoute ) ->
            True

        ( Just (PostEditRoute _), PostViewRoute _ ) ->
            True

        ( Just (PostEditRoute _), PostsListRoute ) ->
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
            [ center, width (px 900) ]
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


getTagById : ID -> List Tag -> Maybe Tag
getTagById id tags =
    List.filter (\tag -> tag.id == id) tags |> List.head


getPostsByTag : Maybe Tag -> List Post -> List Post
getPostsByTag tag posts =
    case tag of
        Just tag ->
            List.filter (\post -> List.member tag post.tags == True) posts

        Nothing ->
            []


viewContent : Model -> List (Element Styles Variations Msg)
viewContent model =
    case model.currentRoute of
        Just PostsListRoute ->
            [ viewPostsList model.posts ]

        Just (PostsListByTagRoute tagId) ->
            let
                tag =
                    getTagById tagId model.tags

                posts =
                    getPostsByTag tag model.posts
            in
                [ viewPostsListByTag tag posts ]

        Just (PostViewRoute slug) ->
            [ getPostBySlug slug model.posts |> viewPost ]

        Just (PostEditRoute slug) ->
            [ getPostBySlug slug model.posts |> viewPostEdit ]

        Just AboutRoute ->
            [ viewAbout ]

        Nothing ->
            [ viewPostsList model.posts ]



-- POST VIEWS


viewPost : Maybe Post -> Element Styles Variations Msg
viewPost post =
    case post of
        Just post ->
            column None
                [ spacing 5 ]
                [ viewPostMeta post
                , paragraph PostTitle [ vary Link False ] [ text post.title ]
                , el None
                    [ width (px 900), class "post-body" ]
                    (viewPostBody post.body |> html)
                , viewTags post.tags
                ]
                |> article

        Nothing ->
            column None
                [ spacing 10 ]
                [ paragraph PostTitle [] [ text "Nothing found" ] ]


viewPostEdit : Maybe Post -> Element Styles Variations Msg
viewPostEdit post =
    let
        input inputElement variations label_ value =
            label LabelStyle [] (text label_) <|
                inputElement TextInputStyle ((paddingXY 0 5) :: variations) value
    in
        case post of
            Just post ->
                column None
                    [ spacing 30, width (px 900) ]
                    [ column None
                        [ spacing 5 ]
                        [ viewPostMeta post
                        , paragraph PostTitle [] [ text "Edit Post" ]
                        ]
                    , input inputText [] "Title" post.title
                    , el None [] (text "Is Published?") |> checkbox post.isPublished None []
                    , input textArea [] "Description" post.description
                    , input inputText [] "Project" post.title
                    , input inputText [] "Tags" post.title
                    , input textArea [ rows 25 ] "Body" post.markdown
                    ]

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
        , viewLink PostTitle [ vary Link True ] post.title (PostViewRoute post.slug)
        , paragraph None [] [ text post.description ]
        , viewTags post.tags
        ]


viewPostsList : List Post -> Element Styles Variations Msg
viewPostsList posts =
    column None [ spacing 100 ] (List.map viewPostsListItem posts)


viewPostsListByTag : Maybe Tag -> List Post -> Element Styles Variations Msg
viewPostsListByTag tag posts =
    case tag of
        Just tag ->
            column None
                [ spacing 50 ]
                [ row None
                    [ spacing 20 ]
                    [ paragraph None [] [ text "Posts by tag" ]
                    , viewTag tag
                    ]
                , column None [ spacing 100 ] (List.map viewPostsListItem posts)
                ]

        Nothing ->
            column None
                [ spacing 10 ]
                [ paragraph PostTitle [] [ text "Nothing found" ] ]


viewTagsList : List Tag -> Element Styles Variations Msg
viewTagsList tags =
    column None
        [ spacing 10, width (px 150) ]
        (List.map viewTag tags)


viewTag : Tag -> Element Styles Variations Msg
viewTag tag =
    viewLink TagStyle [ paddingXY 10 0 ] tag.name (PostsListByTagRoute tag.id)


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
        imageUrl =
            getGravatarUrl email "?s=200"
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
        el None
            [ justify ]
            (row None
                [ paddingTop 80, paddingBottom 80, spacing 40 ]
                [ viewLink Logo [] "igor kuzmenko_" PostsListRoute
                , row None
                    [ spacing 40 ]
                    [ navLink "blog" PostsListRoute
                    , navLink "about" AboutRoute
                    ]
                    |> nav
                , el NavOption [] (text "rss") |> link "http://feeds.feedburner.com/kuzzmi"
                ]
            )


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


makeApiCall : String -> (Result Http.Error a -> Msg) -> Decode.Decoder a -> Cmd Msg
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


getTags : Cmd Msg
getTags =
    makeApiCall "tags" LoadTags tagsDecoder



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
        |> Pipeline.required "_id" Decode.string
        |> Pipeline.required "name" Decode.string


basePostDecoder : Decode.Decoder Post
basePostDecoder =
    decode Post
        |> Pipeline.required "_id" Decode.string
        |> Pipeline.required "title" Decode.string
        |> Pipeline.required "body" Decode.string
        |> Pipeline.required "markdown" Decode.string
        |> Pipeline.required "dateCreated" dateDecoder
        |> Pipeline.required "isPublished" Decode.bool
        |> Pipeline.required "slug" Decode.string
        |> Pipeline.required "description" (Decode.map (Maybe.withDefault "") (Decode.nullable Decode.string))
        |> Pipeline.required "tags" (Decode.list tagDecoder)


postsDecoder : Decode.Decoder (List Post)
postsDecoder =
    Decode.field "posts" (Decode.list basePostDecoder)


tagsDecoder : Decode.Decoder (List Tag)
tagsDecoder =
    Decode.field "tags" (Decode.list tagDecoder)
