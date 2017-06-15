module Models exposing (..)

import Date


type Route
    = PostsListRoute
    | PostsListByTagRoute ID
    | PostViewRoute Slug
    | PostNewRoute
    | PostEditRoute Slug
    | ProjectsListRoute
    | LoginRoute
    | AboutRoute


type alias Tag =
    { id : ID
    , name : String
    }


type alias Slug =
    String


type alias Model =
    { posts : List Post
    , tags : List Tag
    , post : Maybe Post
    , creds : Credentials
    , accessToken : Token
    , apiUrl : String
    , currentRoute : Maybe Route
    }


type alias Token =
    Maybe String


type alias Credentials =
    { username : String
    , password : String
    , isError : Bool
    }


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
