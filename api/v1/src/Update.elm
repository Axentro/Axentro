module Update exposing (..)

import Http
import Messages exposing (Method, Msg(..), Url, Page(..))
import Models exposing (Model)
import Navi exposing (urlUpdate)
import HttpBuilder exposing (get, post, put, send, withBody, withExpect, withExpectJson, withJsonBody)
import Json.Decode as Decode exposing (Decoder, andThen, bool, decodeString, decodeValue, dict, field, int, keyValuePairs, list, map, maybe, oneOf, string, succeed)
import Json.Decode.Pipeline exposing (decode, hardcoded, optional, required, requiredAt, resolve)


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        UrlChange location ->
            urlUpdate location model

        NavMsg state ->
            ( { model | navState = state }
            , Cmd.none
            )

        RunApiCall method url ->
            ( model, Http.send RunApiCallResponse (Http.getString url) )

        RunApiCallResponse (Ok json) ->
            let
                _ =
                    Debug.log "here " json
            in
                ( { model | apiResponse = json }, Cmd.none )

        RunApiCallResponse (Err err) ->
            ( { model | error = (toString err) }, Cmd.none )

        SetApiUrl page url ->
            case page of
                ApiBlockchain ->
                    ( { model | apiUrlB1 = url }, Cmd.none )

                ApiBlockchainHeader ->
                    ( { model | apiUrlB2 = url }, Cmd.none )

                ApiBlockchainSize ->
                    ( { model | apiUrlB3 = url }, Cmd.none )

                ApiBlock ->
                    ( { model | apiUrlB4 = url }, Cmd.none )

                ApiBlockHeader ->
                    ( { model | apiUrlB5 = url }, Cmd.none )

                ApiBlockTransactions ->
                    ( { model | apiUrlB6 = url }, Cmd.none )

                _ ->
                    ( { model | apiUrlB1 = url }, Cmd.none )
