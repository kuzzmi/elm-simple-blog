module Api exposing (..)

import Http
import Date
import Models exposing (..)
import Json.Encode as Encode
import Json.Decode as Decode
import Json.Decode.Pipeline as Pipeline exposing (decode, required)
import Msg exposing (..)


makeRequest apiUrl token method body endpoint message decoder =
    let
        headers =
            case token of
                Just token_ ->
                    [ Http.header "Authorization" ("Bearer " ++ token_) ]

                Nothing ->
                    []
    in
        Http.send message
            (Http.request
                { method = method
                , headers = headers
                , url = apiUrl ++ endpoint
                , body = body
                , timeout = Nothing
                , expect = Http.expectJson decoder
                , withCredentials = False
                }
            )


makePostRequest requester value =
    requester "POST" (Http.jsonBody value)


makePutRequest requester value =
    requester "PUT" (Http.jsonBody value)


makeGetRequest requester =
    requester "GET" Http.emptyBody


makeDeleteRequest requester =
    requester "DELETE" Http.emptyBody



-- getPosts : Token -> Cmd Msg


getPosts requester =
    makeGetRequest requester "posts" LoadPosts postsDecoder



-- postPost : Token -> Post -> Cmd Msg


postPost requester post =
    makePostRequest requester (postEncoder post) "posts" PostAdd (Decode.field "post" postDecoder)



-- deletePost : Token -> Post -> Cmd Msg


deletePost requester post =
    makeDeleteRequest requester ("posts/" ++ post.id) PostAdd (Decode.field "post" postDecoder)



-- updatePost : Token -> Post -> Cmd Msg


updatePost requester post =
    makePutRequest requester (postEncoder post) ("posts/" ++ post.id) PostUpdate (Decode.field "post" postDecoder)



-- getTags : Token -> Cmd Msg


getTags requester =
    makeGetRequest requester "tags" LoadTags tagsDecoder



-- postCreds : Token -> Credentials -> Cmd Msg


postCreds requester creds =
    makePostRequest requester (credsEncoder creds) "auth/local" GetAccessToken tokenDecoder



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
