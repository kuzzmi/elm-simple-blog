module Msg exposing (Msg(..))

import Models exposing (..)
import Http
import Navigation exposing (Location)
import Window exposing (Size)


type Msg
    = LoadTags (Result Http.Error (List Tag))
      -- posts CRUD operations
    | LoadPosts (Result Http.Error (List Post))
    | PostAdd (Result Http.Error Post)
    | PostUpdate (Result Http.Error Post)
    | PostDelete Post
    | PostSaveOrCreate Post
      -- projects CRUD operations
    | LoadProjects (Result Http.Error (List Project))
      -- auth
    | GetAccessToken (Result Http.Error Token)
    | Login
      -- post form
    | UpdatePostTitle Post String
    | UpdatePostMarkdown Post String
    | UpdatePostIsPublished Post Bool
    | UpdatePostDescription Post String
      -- auth
    | UpdateCreds Credentials
      -- routing
    | ChangeRoute Route
    | UrlChange Location
      -- misc
    | WindowResize Size
    | DoNothing String
