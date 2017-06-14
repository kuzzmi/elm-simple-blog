module Routing exposing (..)

import Models exposing (..)
import UrlParser exposing (Parser, (</>), s, string, oneOf, parsePath)
import Navigation exposing (Location, newUrl)


navigateToRoute : Route -> Cmd msg
navigateToRoute route =
    routeToPath route |> newUrl


parse : Location -> Maybe Route
parse location =
    parsePath routeParser location


routeParser : Parser (Route -> a) a
routeParser =
    oneOf
        [ UrlParser.map PostsListRoute (s "blog")
        , UrlParser.map PostsListByTagRoute (s "blog" </> s "tags" </> string)
        , UrlParser.map PostNewRoute (s "blog" </> s "new")
        , UrlParser.map PostViewRoute (s "blog" </> string)
        , UrlParser.map PostEditRoute (s "blog" </> string </> s "edit")
        , UrlParser.map ProjectsListRoute (s "projects")
        , UrlParser.map LoginRoute (s "login")
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

        PostNewRoute ->
            "/blog/new"

        ProjectsListRoute ->
            "/projects"

        LoginRoute ->
            "/login"

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

        ( Just PostNewRoute, PostsListRoute ) ->
            True

        ( Just (PostEditRoute _), PostsListRoute ) ->
            True

        ( Just AboutRoute, AboutRoute ) ->
            True

        ( _, _ ) ->
            False
