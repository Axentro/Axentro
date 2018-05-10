module Update exposing (..)

import Http exposing (Request, expectString, request, stringBody)
import Messages exposing (Method(GET), Msg(..), Page(..), Url)
import Models exposing (Model)
import Navi exposing (urlUpdate)
import HttpBuilder exposing (get, post, put, send, withBody, withExpect, withExpectJson, withJsonBody)
import Json.Decode as Decode exposing (Decoder, andThen, bool, decodeString, decodeValue, dict, field, int, keyValuePairs, list, map, maybe, oneOf, string, succeed)
import Json.Decode.Pipeline exposing (decode, hardcoded, optional, required, requiredAt, resolve)
import Json.Encode as Encode

update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        UrlChange location ->
            urlUpdate location model

        NavMsg state ->
            ( { model | navState = state }
            , Cmd.none
            )

        RunApiCall method url maybeBody ->
            case method of
                GET ->
                    ( model, Http.send RunApiCallResponse (Http.getString url) )

                _ ->
                    ( model, Http.send RunApiCallResponse (postString (Maybe.withDefault "" maybeBody) url) )

        RunApiCallResponse (Ok json) ->
            ( { model | apiResponse = json, error = "" }, Cmd.none )

        RunApiCallResponse (Err err) ->
            let
             _ = Debug.log "error: " err
            in
             ( { model | apiResponse = "", error = (toString err) }, Cmd.none )

        SetApiBody body ->
             ( { model | apiBody = body }, Cmd.none )

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

                ApiTransaction ->
                    ( { model | apiUrlT1 = url }, Cmd.none )

                ApiTransactionBlock ->
                    ( { model | apiUrlT2 = url }, Cmd.none )

                ApiTransactionBlockHeader ->
                    ( { model | apiUrlT3 = url }, Cmd.none )

                ApiTransactionConfirmations ->
                    ( { model | apiUrlT4 = url }, Cmd.none )

                ApiTransactionFees ->
                    ( { model | apiUrlT5 = url }, Cmd.none )

                ApiAddressTransactions ->
                    ( { model | apiUrlA1 = url }, Cmd.none )

                ApiAddressConfirmed ->
                    ( { model | apiUrlA2 = url }, Cmd.none )

                ApiAddressConfirmedToken ->
                    ( { model | apiUrlA3 = url }, Cmd.none )

                ApiAddressUnconfirmed ->
                    ( { model | apiUrlA4 = url }, Cmd.none )

                ApiAddressUnconfirmedToken ->
                    ( { model | apiUrlA5 = url }, Cmd.none )

                ApiDomainTransactions ->
                    ( { model | apiUrlD1 = url }, Cmd.none )

                ApiDomainConfirmed ->
                    ( { model | apiUrlD2 = url }, Cmd.none )

                ApiDomainConfirmedToken ->
                    ( { model | apiUrlD3 = url }, Cmd.none )

                ApiDomainUnconfirmed ->
                    ( { model | apiUrlD4 = url }, Cmd.none )

                ApiDomainUnconfirmedToken ->
                    ( { model | apiUrlD5 = url }, Cmd.none )

                ApiScarsSales ->
                    ( { model | apiUrlS1 = url }, Cmd.none )

                ApiScarsConfirmed ->
                    ( { model | apiUrlS2 = url }, Cmd.none )

                ApiScarsUnconfirmed ->
                    ( { model | apiUrlS3 = url }, Cmd.none )

                _ ->
                    ( model, Cmd.none )



postString : String -> String -> Request String
postString body url =
  request
    { method = "POST"
    , headers = []
    , url = url
    , body = stringBody "application/json" body
    , expect = expectString
    , timeout = Nothing
    , withCredentials = False
    }