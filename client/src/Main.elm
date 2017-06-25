port module Main exposing (main, setDisqusIdentifier)

import Html
import Element exposing (..)
import Element.Events exposing (..)
import Element.Attributes exposing (..)
import Html.Attributes
import Navigation exposing (programWithFlags, Location)
import Json.Encode as Encode exposing (string)
import Date
import Date.Extra as Date
import Dom.Scroll
import Task
import Debug
import Gravatar exposing (getGravatarUrl)
import Styles exposing (..)
import Models exposing (..)
import Routing
import Api
import Msg exposing (..)
import Color


{-| This is used to update page identificator of the page for disqus
-}
port setDisqusIdentifier : Slug -> Cmd msg


{-| This is used to update localStorage with accessToken
-}
port saveAccessTokenToLocalStorage : Token -> Cmd msg


type alias Flags =
    { accessToken : Token
    , apiUrl : String
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
    let
        requester =
            Api.makeRequest flags.apiUrl flags.accessToken
    in
        ( { posts = []
          , tags = []
          , post = Nothing
          , creds =
                { username = ""
                , password = ""
                , isError = False
                }
          , projects = []
          , accessToken = flags.accessToken
          , apiUrl = flags.apiUrl
          , currentRoute = Routing.parse location
          }
        , Cmd.batch
            [ Api.getPosts requester
            , Api.getTags requester
            , Api.getProjects requester
            ]
        )



-- UPDATE


scrollToTopCmd : Cmd Msg
scrollToTopCmd =
    Dom.Scroll.toTop "body"
        |> Task.attempt (always (DoNothing ""))


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    let
        requester =
            Api.makeRequest model.apiUrl model.accessToken
    in
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
                    , Api.deletePost requester post
                    , Routing.navigateToRoute PostsListRoute
                    ]
                )

            LoadProjects (Ok projects) ->
                ( { model | projects = projects }, Cmd.none )

            LoadProjects (Err _) ->
                ( model, Cmd.none )

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

            -- post form
            UpdatePostTitle post title ->
                ( { model | post = Just { post | title = title } }, Cmd.none )

            UpdatePostDescription post description ->
                ( { model | post = Just { post | description = description } }, Cmd.none )

            UpdatePostMarkdown post markdown ->
                ( { model | post = Just { post | markdown = markdown } }, Cmd.none )

            UpdatePostIsPublished post isPublished ->
                ( { model | post = Just { post | isPublished = isPublished } }, Cmd.none )

            -- auth
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
                            Api.postPost
                        else
                            Api.updatePost
                in
                    ( model
                    , method requester post
                    )

            Login ->
                ( model, Cmd.batch [ Api.postCreds requester model.creds ] )

            GetAccessToken (Ok token) ->
                ( { model | accessToken = token }
                , Cmd.batch
                    [ saveAccessTokenToLocalStorage token
                    , Api.getPosts requester
                    , Api.getProjects requester
                    , Api.getTags requester
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
                [ viewProjectsList isAuthorized model.projects ]

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
            , viewError creds.isError "Looks like credentials are not correct or there is another problem"
            , input TextInput [ onInput updateUsername ] "Username" creds.username
            , input PasswordInput [ onInput updatePassword ] "Password" creds.password
            , el None [ center ] (viewButtonText ButtonStyle [] "Login" Login)
            ]



-- PROJECT VIEWS


viewProjectsListItem : Bool -> Project -> Element Styles Variations Msg
viewProjectsListItem isAuthorized project =
    column None
        [ spacing 5, width (percent 50) ]
        [ -- image project.imageUrl None [] (text (project.name ++ " image")),
          el PostTitle [ vary Link True ] (text project.name) |> link project.url
        , paragraph None [] [ text project.description ]
        , viewIconLabeled LightButtonStyle "favorite_border" (toString project.stars)
        ]


viewProjectsList : Bool -> List Project -> Element Styles Variations Msg
viewProjectsList isAuthorized projects =
    let
        viewProjectsListItem_ =
            viewProjectsListItem isAuthorized
    in
        column None
            [ spacing 50 ]
            [ viewButtonsRow (isAuthorized)
                [ viewButtonText ButtonStyle [ paddingXY 10 0 ] "new project" (ChangeRoute PostNewRoute)
                , viewButtonText ButtonStyle [ paddingXY 10 0 ] "sync projects" (ChangeRoute PostNewRoute)
                ]
            , wrappedRow None [ spacing 100 ] (List.map viewProjectsListItem_ projects)
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
                    [ viewButtonText ButtonStyle [] "edit" (ChangeRoute <| PostEditRoute post.slug)
                    ]
                , paragraph PostTitle [ vary Link False ] [ text post.title ]
                , el None
                    [ width (px 900), class "post-body" ]
                    (viewPostBody post.body |> html)
                , viewTags post.tags
                ]
                |> article

        Nothing ->
            viewNothingFound


viewPostEdit : Bool -> Maybe Post -> Element Styles Variations Msg
viewPostEdit isAuthorized post =
    let
        togglePublish post =
            PostSaveOrCreate { post | isPublished = not post.isPublished }

        publishButton post =
            if post.isPublished then
                viewButtonText ButtonStyle [] "unpublish" (togglePublish post)
            else
                viewButtonText ButtonStyle [] "publish" (togglePublish post)
    in
        case post of
            Just post ->
                column None
                    [ spacing 30, width (px 900) ]
                    [ column None
                        [ spacing 5 ]
                        [ viewPostMeta isAuthorized
                            post
                            [ viewButtonText ButtonStyle [] "save" (PostSaveOrCreate post)
                            , viewButtonText ButtonStyle [] "cancel" (ChangeRoute PostsListRoute)
                            , when (String.length post.id > 0) (publishButton post)
                            , when (String.length post.id > 0) (viewButtonText ButtonStyle [] "delete" (PostDelete post))
                            ]
                        , paragraph PostTitle [] [ text "Edit Post" ]
                        ]
                    , input TextInput [ onInput (UpdatePostTitle post) ] "Title" post.title
                    , input TextAreaInput [ onInput (UpdatePostDescription post) ] "Description" post.description
                    , input TextInput [] "Project" post.title
                    , input TextInput [] "Tags" post.title

                    --    , input "text" [ onInput updateUsername ] "Username" creds.username
                    , input TextAreaInput [ rows 25, onInput (UpdatePostMarkdown post) ] "Body" post.markdown
                    ]

            Nothing ->
                column None
                    [ spacing 10 ]
                    [ paragraph PostTitle [] [ text "Nothing found" ] ]


viewPostStatus : Bool -> Element Styles Variations Msg
viewPostStatus isPublished =
    when (isPublished == False) (el LabelStyle [] (text "DRAFT"))


viewClickable style attributes msg content =
    el style (onClick msg :: attributes) content


viewButtonText style attributes label msg =
    viewClickable style (paddingXY 10 0 :: attributes) msg (text label)


viewButtonIconText style icon label msg =
    viewClickable style [ paddingXY 10 0 ] msg (viewIconLabeled None icon label)


viewButtonIcon style icon msg =
    viewClickable style [ paddingXY 10 0 ] msg (viewIcon None icon)


viewIcon style iconName =
    el style [ class "material-icons" ] (text iconName) |> node "i"


viewIconLabeled iconStyle iconName label =
    row None
        [ verticalCenter, spacing 10 ]
        [ viewIcon iconStyle iconName
        , el None [] (text label)
        ]


viewButtonsRow when_ buttons =
    when when_ (row None [ spacing 10 ] buttons)


viewError when_ text_ =
    when when_ <| el ErrorStyle [ paddingXY 20 10 ] (text text_)


type InputType
    = TextInput
    | PasswordInput
    | TextAreaInput


input inputType variations label_ value_ =
    case inputType of
        TextInput ->
            label LabelStyle [] (text label_) <|
                node "input" <|
                    el TextInputStyle (paddingXY 0 5 :: type_ "text" :: value value_ :: variations) empty

        PasswordInput ->
            label LabelStyle [] (text label_) <|
                node "input" <|
                    el TextInputStyle (paddingXY 0 5 :: type_ "password" :: value value_ :: variations) empty

        TextAreaInput ->
            label LabelStyle [] (text label_) <|
                textArea TextInputStyle (paddingXY 0 5 :: variations) value_


viewPostMeta : Bool -> Post -> List (Element Styles Variations Msg) -> Element Styles Variations Msg
viewPostMeta isAuthorized post buttons =
    row None
        [ justify ]
        [ row None
            [ spacing 30 ]
            [ viewPostStatus post.isPublished
            , el None [] (Date.toFormattedString "MMMM ddd, y" post.dateCreated |> text)
            ]
        , viewButtonsRow isAuthorized buttons
        ]



-- add disqus count https://help.disqus.com/customer/portal/articles/565624


viewPostsListItem : Bool -> Post -> Element Styles Variations Msg
viewPostsListItem isAuthorized post =
    column None
        [ spacing 5 ]
        [ viewPostMeta isAuthorized
            post
            [ viewButtonText ButtonStyle [] "edit" (ChangeRoute <| PostEditRoute post.slug)
            ]
        , viewClickable PostTitle [ vary Link True ] (ChangeRoute <| PostViewRoute post.slug) (text post.title)
        , paragraph None [ paddingBottom 10 ] [ text post.description ]
        , viewTags post.tags
        , row None
            [ spacing 30 ]
            [ viewIconLabeled LightButtonStyle "favorite_border" "9"
            , viewIconLabeled LightButtonStyle "chat_bubble_outline" "12"
            ]
        ]


viewPostsList : Bool -> List Post -> Element Styles Variations Msg
viewPostsList isAuthorized posts =
    let
        viewPostsListItem_ =
            viewPostsListItem isAuthorized
    in
        column None
            [ spacing 50 ]
            [ when (isAuthorized == True)
                (el None
                    [ alignLeft ]
                    (viewButtonText ButtonStyle [ paddingXY 10 0 ] "new post" (ChangeRoute PostNewRoute))
                )
            , column None [ spacing 100 ] (List.map viewPostsListItem_ posts)
            ]


viewNothingFound =
    el None
        []
        (paragraph PostTitle [] [ text "Nothing found" ])


viewPostsListByTag : Bool -> Maybe Tag -> List Post -> Element Styles Variations Msg
viewPostsListByTag isAuthorized tag posts =
    case tag of
        Just tag ->
            column None
                [ spacing 10, center ]
                [ --viewIconLabeled LightButtonStyle "label_outline" tag.name
                  row None [ verticalCenter, spacing 20 ] [ text "All posts by label:", viewTag tag ]
                , viewPostsList isAuthorized posts
                ]

        Nothing ->
            viewNothingFound


viewTagsList : List Tag -> Element Styles Variations Msg
viewTagsList tags =
    column None
        [ spacing 10, width (px 150) ]
        (List.map viewTag tags)


viewTag : Tag -> Element Styles Variations Msg
viewTag tag =
    viewButtonText TagStyle [ paddingXY 10 0 ] tag.name (ChangeRoute <| PostsListByTagRoute tag.id)


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
            viewButtonText NavOption [ vary Active (isActive route), paddingXY 15 0 ] label (ChangeRoute route)
    in
        row None
            [ justify ]
            [ row None
                [ paddingTop 80, paddingBottom 80, spacing 40 ]
                [ viewButtonText Logo [] "igor kuzmenko_" (ChangeRoute PostsListRoute)
                , row None
                    [ spacing 40 ]
                    [ navLink "blog" PostsListRoute
                    , navLink "projects" ProjectsListRoute
                    , navLink "about" AboutRoute
                    , when (isAuthorized == False) (navLink "login" LoginRoute)
                    ]
                    |> nav
                ]
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
