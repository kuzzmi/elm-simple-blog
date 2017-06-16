module Msg exposing (Msg(..))

import Models exposing (..)
import Http
import Navigation exposing (Location)


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
