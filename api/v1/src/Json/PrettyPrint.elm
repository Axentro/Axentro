module Json.PrettyPrint exposing (..)

import Json.Decode
import Dict exposing (Dict)


type InternalJson
    = JsonString String
    | JsonNumber Float
    | JsonBool Bool
    | JsonObject (Dict String InternalJson)
    | JsonList (List InternalJson)


decodeToInternalJson : Json.Decode.Decoder InternalJson
decodeToInternalJson =
    Json.Decode.oneOf
        [ Json.Decode.map JsonString Json.Decode.string
        , Json.Decode.map JsonNumber Json.Decode.float
        , Json.Decode.map JsonBool Json.Decode.bool
        , Json.Decode.map JsonObject (Json.Decode.lazy (\_ -> Json.Decode.dict decodeToInternalJson))
        , Json.Decode.map JsonList (Json.Decode.lazy (\_ -> (Json.Decode.list decodeToInternalJson)))
        ]


toString : Json.Decode.Value -> String
toString value =
    case Json.Decode.decodeValue decodeToInternalJson value of
        Err e ->
            e

        Ok v ->
            internalJsonToString v


stringify : String -> String
stringify value =
    case Json.Decode.decodeString decodeToInternalJson value of
        Err e ->
            e

        Ok v ->
            internalJsonToString v


internalJsonToString : InternalJson -> String
internalJsonToString json =
    case json of
        JsonString str ->
            "\"" ++ str ++ "\""

        JsonNumber num ->
            Basics.toString num

        JsonBool bool ->
            if bool then
                "true"
            else
                "false"

        JsonObject object ->
            Dict.toList object
                |> List.map (\( key, value ) -> "\"" ++ key ++ "\" : " ++ internalJsonToString value)
                |> String.join ",\n"
                |> (\x -> "{\n" ++ x ++ "}")

        JsonList list ->
            List.map internalJsonToString list
                |> String.join ", "
                |> (\x -> "[" ++ x ++ "]")