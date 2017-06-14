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
import Navigation exposing (programWithFlags, Location)
import Date
import Date.Extra as Date
import Dom.Scroll
import Task
import Debug
import Styles exposing (..)
import Gravatar exposing (getGravatarUrl)
import Models exposing (..)
import Routing


{-| This is used to update page identificator of the page for disqus
-}
port setDisqusIdentifier : Slug -> Cmd msg


{-| This is used to update localStorage with accessToken
-}
port saveAccessTokenToLocalStorage : Token -> Cmd msg


type alias Flags =
    { accessToken : Token
    }


main =
    Navigation.programWithFlags UrlChange
        { init = init
        , view = view
        , update = update
        , subscriptions = subscriptions
        }



-- MODEL


emptyPost : Maybe Post
emptyPost =
    Just
        { id = ""
        , title = ""
        , body = ""
        , markdown = ""
        , dateCreated = Date.fromTime 0
        , isPublished = False
        , slug = ""
        , description = ""
        , tags = []
        }


init : Flags -> Location -> ( Model, Cmd Msg )
init flags location =
    ( { posts = []
      , tags = []
      , post = Nothing
      , creds =
            { username = ""
            , password = ""
            , isError = False
            }
      , accessToken = flags.accessToken
      , currentRoute = Routing.parse location
      }
    , Cmd.batch [ getPosts flags.accessToken, getTags flags.accessToken ]
    )



-- UPDATE


type Msg
    = LoadTags (Result Http.Error (List Tag))
      -- posts CRUD operations
    | LoadPosts (Result Http.Error (List Post))
    | PostAdd (Result Http.Error Post)
    | PostUpdate (Result Http.Error Post)
    | PostDelete Post
    | PostSaveOrCreate Post
      -- auth
    | GetAccessToken (Result Http.Error Token)
    | Login
      -- forms
    | UpdatePost Post
    | UpdateCreds Credentials
      -- routing
    | ChangeRoute Route
    | UrlChange Location
      -- misc
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

        PostAdd (Ok post) ->
            ( { model | posts = post :: model.posts }
            , Routing.navigateToRoute (PostViewRoute post.slug)
            )

        PostAdd (Err _) ->
            ( model, Cmd.none )

        PostUpdate (Ok post) ->
            let
                update post_ =
                    if post_.id == post.id then
                        post
                    else
                        post_
            in
                ( { model | posts = List.map update model.posts }
                , Routing.navigateToRoute (PostViewRoute post.slug)
                )

        PostUpdate (Err _) ->
            ( model, Cmd.none )

        PostDelete post ->
            ( { model | posts = List.filter (\post_ -> post_.id /= post.id) model.posts }
            , Cmd.batch
                [ scrollToTopCmd
                , deletePost model.accessToken post
                , Routing.navigateToRoute PostsListRoute
                ]
            )

        LoadTags (Ok tags) ->
            ( { model | tags = tags }, Cmd.none )

        LoadTags (Err _) ->
            ( model, Cmd.none )

        UrlChange location ->
            let
                route =
                    Routing.parse location
            in
                case route of
                    Just (PostViewRoute slug) ->
                        ( { model | currentRoute = route }
                        , Cmd.batch [ scrollToTopCmd, setDisqusIdentifier slug ]
                        )

                    _ ->
                        ( { model | currentRoute = route }
                        , scrollToTopCmd
                        )

        UpdatePost post ->
            ( { model | post = Just post }, Cmd.none )

        UpdateCreds creds ->
            ( { model | creds = creds }, Cmd.none )

        ChangeRoute route ->
            let
                scrollAndGo =
                    Cmd.batch [ scrollToTopCmd, Routing.navigateToRoute route ]
            in
                case route of
                    PostEditRoute slug ->
                        ( { model | post = getPostBySlug slug model.posts }
                        , scrollAndGo
                        )

                    PostNewRoute ->
                        ( { model | post = emptyPost }, scrollAndGo )

                    _ ->
                        ( model, scrollAndGo )

        PostSaveOrCreate post ->
            let
                isNew =
                    if post.id == "" then
                        True
                    else
                        False

                method =
                    if isNew then
                        postPost
                    else
                        updatePost
            in
                ( model
                , method model.accessToken post
                )

        Login ->
            ( model, Cmd.batch [ postCreds Nothing model.creds ] )

        GetAccessToken (Ok token) ->
            ( { model | accessToken = token }
            , Cmd.batch
                [ saveAccessTokenToLocalStorage token
                , getPosts token
                , getTags token
                , Routing.navigateToRoute PostsListRoute
                ]
            )

        GetAccessToken (Err _) ->
            let
                newCreds creds =
                    { creds | isError = True }
            in
                ( { model | creds = newCreds model.creds }, Cmd.none )

        DoNothing _ ->
            ( model, Cmd.none )



-- MAIN VIEW


isAuthorized : Token -> Bool
isAuthorized token =
    case token of
        Just _ ->
            True

        Nothing ->
            False


view : Model -> Html.Html Msg
view model =
    column None
        []
        [ column Main
            [ center, width (px 900) ]
            [ viewHeader (model.accessToken /= Nothing) model.currentRoute
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
    let
        isAuthorized =
            model.accessToken /= Nothing
    in
        case model.currentRoute of
            Just PostsListRoute ->
                [ viewPostsList isAuthorized model.posts ]

            Just (PostsListByTagRoute tagId) ->
                let
                    tag =
                        getTagById tagId model.tags

                    posts =
                        getPostsByTag tag model.posts
                in
                    [ viewPostsListByTag isAuthorized tag posts ]

            Just (PostViewRoute slug) ->
                [ getPostBySlug slug model.posts |> viewPost isAuthorized ]

            Just (PostEditRoute slug) ->
                [ viewPostEdit isAuthorized model.post ]

            Just PostNewRoute ->
                [ viewPostEdit isAuthorized model.post ]

            Just ProjectsListRoute ->
                [ viewLogin isAuthorized model.creds ]

            Just AboutRoute ->
                [ viewAbout isAuthorized ]

            Just LoginRoute ->
                [ viewLogin isAuthorized model.creds ]

            Nothing ->
                [ viewPostsList isAuthorized model.posts ]



-- LOGIN VIEW


viewLogin : Bool -> Credentials -> Element Styles Variations Msg
viewLogin isAuthorized creds =
    let
        input inputElement variations label_ value =
            label LabelStyle [] (text label_) <|
                inputElement TextInputStyle ((paddingXY 0 5) :: variations) value

        updatePassword password =
            UpdateCreds { creds | password = password }

        updateUsername username =
            UpdateCreds { creds | username = username }
    in
        column None
            [ spacing 30, width (px 900) ]
            [ column None
                [ spacing 5 ]
                [ paragraph PostTitle [] [ text "Login" ]
                ]
            , when (creds.isError == True) (el ErrorStyle [ paddingXY 20 10 ] (text "Looks like credentials are not correct or there is another problem"))
            , input inputText [ onInput updateUsername ] "Username" creds.username
            , input inputText [ onInput updatePassword ] "Password" creds.password
            , el None [ center ] (viewButton "Login" Login)
            ]



-- POST VIEWS


viewPost : Bool -> Maybe Post -> Element Styles Variations Msg
viewPost isAuthorized post =
    case post of
        Just post ->
            column None
                [ spacing 5 ]
                [ viewPostMeta isAuthorized
                    post
                    [ viewLink ButtonStyle [ paddingXY 10 0 ] "edit" (PostEditRoute post.slug)
                    , when (post.isPublished == False) (viewButton "publish" (PostSaveOrCreate { post | isPublished = not post.isPublished }))
                    , when (post.isPublished == True) (viewButton "unpublish" (PostSaveOrCreate { post | isPublished = not post.isPublished }))
                    , viewButton "delete" (PostDelete post)
                    ]
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


viewPostEdit : Bool -> Maybe Post -> Element Styles Variations Msg
viewPostEdit isAuthorized post =
    let
        input inputElement variations label_ value =
            label LabelStyle [] (text label_) <|
                inputElement TextInputStyle ((paddingXY 0 5) :: variations) value

        updateMarkdown markdown =
            case post of
                Just post_ ->
                    UpdatePost { post_ | markdown = markdown }

                Nothing ->
                    DoNothing ""

        updateDescription description =
            case post of
                Just post_ ->
                    UpdatePost { post_ | description = description }

                Nothing ->
                    DoNothing ""

        updateTitle title =
            case post of
                Just post_ ->
                    UpdatePost { post_ | title = title }

                Nothing ->
                    DoNothing ""

        updateIsPublished =
            case post of
                Just post_ ->
                    UpdatePost { post_ | isPublished = not post_.isPublished }

                Nothing ->
                    DoNothing ""
    in
        case post of
            Just post ->
                column None
                    [ spacing 30, width (px 900) ]
                    [ column None
                        [ spacing 5 ]
                        [ viewPostMeta isAuthorized
                            post
                            [ viewButton "save" (PostSaveOrCreate post)
                            , when (post.isPublished == False) (viewButton "publish" (PostSaveOrCreate { post | isPublished = not post.isPublished }))
                            , when (post.isPublished == True) (viewButton "unpublish" (PostSaveOrCreate { post | isPublished = not post.isPublished }))
                            ]
                        , paragraph PostTitle [] [ text "Edit Post" ]
                        ]
                    , input inputText [ onInput updateTitle ] "Title" post.title
                    , el None [] (text "Is Published?") |> checkbox post.isPublished None [ onClick updateIsPublished ]
                    , input textArea [ onInput updateDescription ] "Description" post.description
                    , input inputText [] "Project" post.title
                    , input inputText [] "Tags" post.title
                    , input textArea [ rows 25, onInput updateMarkdown ] "Body" post.markdown
                    ]

            Nothing ->
                column None
                    [ spacing 10 ]
                    [ paragraph PostTitle [] [ text "Nothing found" ] ]


viewPostStatus : Bool -> Element Styles Variations Msg
viewPostStatus isPublished =
    when (isPublished == False) (el ErrorStyle [ paddingXY 10 0 ] (text "DRAFT"))


viewLink style attributes label route =
    el style ((onClick (ChangeRoute route)) :: attributes) (text label) |> node "a"


viewButton label msg =
    el ButtonStyle [ paddingXY 10 0, onClick msg ] (text label)


viewPostMeta : Bool -> Post -> List (Element Styles Variations Msg) -> Element Styles Variations Msg
viewPostMeta isAuthorized post buttons =
    row None
        [ justify ]
        [ row None
            [ spacing 10 ]
            [ viewPostStatus post.isPublished
            , el None [] (Date.toFormattedString "MMMM ddd, y" post.dateCreated |> text)
            ]
        , when (isAuthorized == True) (row None [ spacing 10 ] buttons)
        ]



-- add disqus count https://help.disqus.com/customer/portal/articles/565624


viewPostsListItem : Bool -> Post -> Element Styles Variations Msg
viewPostsListItem isAuthorized post =
    column None
        [ spacing 5 ]
        [ viewPostMeta isAuthorized
            post
            [ viewLink ButtonStyle [ paddingXY 10 0 ] "edit" (PostEditRoute post.slug)
            , viewButton "delete" (PostDelete post)
            ]
        , viewLink PostTitle [ vary Link True ] post.title (PostViewRoute post.slug)
        , paragraph None [] [ text post.description ]
        , viewTags post.tags
        ]


viewPostsList : Bool -> List Post -> Element Styles Variations Msg
viewPostsList isAuthorized posts =
    let
        viewPostsListItem_ =
            viewPostsListItem isAuthorized
    in
        column None
            [ spacing 50 ]
            [ when (isAuthorized == True) (el None [ alignLeft ] (viewLink ButtonStyle [ paddingXY 10 0 ] "new post" PostNewRoute))
            , column None [ spacing 100 ] (List.map viewPostsListItem_ posts)
            ]


viewPostsListByTag : Bool -> Maybe Tag -> List Post -> Element Styles Variations Msg
viewPostsListByTag isAuthorized tag posts =
    case tag of
        Just tag ->
            column None
                [ spacing 10 ]
                [ row None
                    [ spacing 20 ]
                    [ paragraph None [] [ text "Posts by tag" ]
                    , viewTag tag
                    ]
                , viewPostsList isAuthorized posts
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


viewAbout : Bool -> Element Styles Variations msg
viewAbout isAuthorized =
    column None
        [ spacing 10 ]
        [ viewGravatar "kuzzmi@gmail.com"
        , el None [] (text "Hello, my name is Igor. I love my wife, JavaScript, and Vim.")
        ]



-- MISC


viewHeader : Bool -> Maybe Route -> Element Styles Variations Msg
viewHeader isAuthorized currentRoute =
    let
        isActive route =
            Routing.isRouteActive currentRoute route

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
                    , navLink "projects" AboutRoute
                    , navLink "about" AboutRoute
                    , when (isAuthorized == False) (navLink "login" LoginRoute)
                    ]
                    |> nav

                -- , el NavOption [] (text "rss") |> link "http://feeds.feedburner.com/kuzzmi"
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


makeRequest method body token endpoint message decoder =
    let
        url =
            "//localhost:3000/api/" ++ endpoint

        headers =
            case token of
                Just token_ ->
                    [ Http.header "Authorization" ("Bearer " ++ token_)
                    ]

                Nothing ->
                    []
    in
        Http.send message
            (Http.request
                { method = method
                , headers = headers
                , url = url
                , body = body
                , timeout = Nothing
                , expect = Http.expectJson decoder
                , withCredentials = False
                }
            )


makePostRequest value =
    makeRequest "POST" (Http.jsonBody value)


makePutRequest value =
    makeRequest "PUT" (Http.jsonBody value)


makeGetRequest =
    makeRequest "GET" Http.emptyBody


makeDeleteRequest =
    makeRequest "DELETE" Http.emptyBody


getPosts : Token -> Cmd Msg
getPosts token =
    makeGetRequest token "posts" LoadPosts postsDecoder


postPost : Token -> Post -> Cmd Msg
postPost token post =
    makePostRequest (postEncoder post) token "posts" PostAdd (Decode.field "post" postDecoder)


deletePost : Token -> Post -> Cmd Msg
deletePost token post =
    makeDeleteRequest token ("posts/" ++ post.id) PostAdd (Decode.field "post" postDecoder)


updatePost : Token -> Post -> Cmd Msg
updatePost token post =
    makePutRequest (postEncoder post) token ("posts/" ++ post.id) PostUpdate (Decode.field "post" postDecoder)


getTags : Token -> Cmd Msg
getTags token =
    makeGetRequest token "tags" LoadTags tagsDecoder


postCreds : Token -> Credentials -> Cmd Msg
postCreds token creds =
    makePostRequest (credsEncoder creds) token "auth/local" GetAccessToken tokenDecoder



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


tagEncoder : Tag -> Encode.Value
tagEncoder tag =
    Encode.object
        [ ( "name", Encode.string tag.name )
        , ( "_id", Encode.string tag.id )
        ]


tagsEncoder : List Tag -> List Encode.Value
tagsEncoder tags =
    List.map tagEncoder tags


postDecoder : Decode.Decoder Post
postDecoder =
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


postEncoder : Post -> Encode.Value
postEncoder post =
    Encode.object
        [ ( "post"
          , Encode.object
                [ ( "title", Encode.string post.title )
                , ( "markdown", Encode.string post.markdown )
                , ( "description", Encode.string post.description )
                , ( "isPublished", Encode.bool post.isPublished )
                , ( "tags", Encode.list (tagsEncoder post.tags) )
                ]
          )
        ]


credsEncoder : Credentials -> Encode.Value
credsEncoder creds =
    Encode.object
        [ ( "username", Encode.string creds.username )
        , ( "password", Encode.string creds.password )
        ]


tokenDecoder : Decode.Decoder Token
tokenDecoder =
    Decode.field "access_token"
        (Decode.nullable Decode.string)


postsDecoder : Decode.Decoder (List Post)
postsDecoder =
    Decode.field "posts" (Decode.list postDecoder)


tagsDecoder : Decode.Decoder (List Tag)
tagsDecoder =
    Decode.field "tags" (Decode.list tagDecoder)
