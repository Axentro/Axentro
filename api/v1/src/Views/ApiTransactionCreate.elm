module Views.ApiTransactionCreate exposing (..)

import Html.Events exposing (onClick, onInput)
import Json.PrettyPrint
import Views.TableHelper exposing (docTable)
import Views.ApiLeftNav exposing (apiLeftNav)
import Html exposing (..)
import Html.Attributes exposing (..)
import Models exposing (Model)
import Bootstrap.Navbar as Navbar
import Bootstrap.Grid as Grid
import Bootstrap.Grid.Col as Col
import Bootstrap.Card as Card
import Bootstrap.Card.Block as Block
import Bootstrap.Button as Button
import Bootstrap.ListGroup as Listgroup
import Bootstrap.Modal as Modal
import Bootstrap.Table as Table
import Bootstrap.Alert as Alert
import Bootstrap.Form.Textarea as TextArea
import Bootstrap.Form.Input as Input
import Messages exposing (Method(GET), Msg(..), Page(..))
import Views.ApiDocumentationHelper exposing (documentation)


pageApiTransactionCreate : Model -> List (Html Msg)
pageApiTransactionCreate model =
    let
        description =
            div [] [ Html.text "This retrieves the transaction specified by the transaction id as Json" ]

        ex = """{"status":"success","result":{"id":"da2d2ef81e1ca3f4e1fee7ba06bcb93860349d67d93e066554e17b3fc1c4b5bc","action":"head","senders":[],"recipients":[{"address":"VDBjMTlkMWM0NTZhYmE3ZjdmYmVkMDgwMWFhZTMyMDRhMTUzNjFhYWUwYzk3ODQ5","amount":2500},{"address":"VDAxNmM1OGVkNmYyNzI2NzcyYjYzODRmMzJmMDkzODhjMTczNWI0NDFjZGM5ZTIz","amount":7500}],"message":"0","token":"SHARI","prev_hash":"0"}}"""
    in
        [ br [] []
        , Grid.row []
            [ apiLeftNav ApiTransactionCreate
            , Grid.col [ Col.md9 ]
                [ documentation ApiTransactionCreate model.apiUrlT7 (Just model.apiBody) model.apiResponse "Transaction" description "POST" "api/v1/transaction" (Just requestDescription) Nothing """curl -X POST -H "Content-Type: application/json" -d '{"transaction": {"id":"9581ab8ae3c121cdec9d57613006bae9014a28fb87de2c8c6348adac485d2d4e","action":"send","senders":[{"address":"VDBkYWQxZjZlZjllOTAzYzNiODQ0NmZkZTI4NDBhYmMzYjUxYThjM2E1ZjNkODlj","public_key":"48c45b7e45cd415187216452fa22523e002ca042c2bd7205484f29201c3d5806f90e7aeebad37e3fbe01286c25d4027d3f3fec7b5647eff33c07ebd287b57242","amount":5000,"fee":1,"sign_r":"0","sign_s":"0"}],"recipients":[{"address":"VDBlY2I4ZjA5MTUxOWE0MTIwNTRmZjlhYTM1YjYxMjcwNjM1YzcxYjlkMDZhZDUx","amount":5000}],"message":"","token":"WOOP","prev_hash":"0"}}' http://testnet.sushichain.io:3000/api/v1/transaction""" ex model.error
                ]
            ]
        ]


requestDescription : Html Msg
requestDescription =
   div [] [
    hr [] []
    , Html.h5 [] [ Html.text "Post Body"]
    , p [] [ text "The post body must have a key called transaction with a value of the transaction containing the mandatory fields described below:"]
    , Alert.simpleLight [] [ text """ {"transaction": {"action":"send" ...}} """ ]
    , p [] [ text "The post body is made up of the following mandatory fields:"]
    , ul [] [
     li [] [ text "action"]
     , li [] [ text "senders"]
     , li [] [ text "recipients"]
     , li [] [ text "message"]
     , li [] [ text "token"]
     , li [] [ text "prev_hash"]
     , li [] [ text "signing"]
    ]
    , hr [] []
    , Html.h6 [] [ Html.text "Action"]
    , p [] [ text "action is the type of action to perform - e.g send - is when you want to send some tokens to an address. Send is the most common but there are others like create_token etc as well as those used in scars. Also users can create their own actions as part of building dApps."]
    , Alert.simpleLight [] [ text """ {"action":"send" ...} """ ]
    , hr [] []
    , Html.h6 [] [ Html.text "Senders"]
    , p [] [ text "This is information about where a payment or action originates - e.g. the address from which to send tokens from. It's made up of an address, amount, fee and public key. It's a list of senders but generally there is only one"]
    , Alert.simpleLight [] [ text """ {"senders": [{"address": "the-address", "amount":1000, "fee":1, "public_key":"the-public-key", "sign_r":"0", "sign_s":"0"}] ...}""" ]
    , hr [] []
    , Html.h6 [] [ Html.text "Recipients"]
    , p [] [ text "This is information about when a payment of action is going - e.g. the destination address when sending tokens. It's made up of an address and amount. It's a list of recipients but generally there is only one" ]
    , Alert.simpleLight [] [ text """ {"recipients": [{"address": "the-address", "amount":1000}] ...}""" ]
    , hr [] []
    , Html.h6 [] [ Html.text "Message"]
    , p [] [ text "This is a place to but arbitrary data related to the transaction - for sending tokens it's generally empty - but it's useful when building dapps." ]
    , Alert.simpleLight [] [ text """ {"message": "some message" ...} """ ]
    , hr [] []
    , Html.h6 [] [ Html.text "Token"]
    , p [] [ text "This is the token to use - generally it's SHARI but it can be any other user created token" ]
    , Alert.simpleLight [] [ text """ {"token": "SHARI" ...} """ ]
    , hr [] []
    , Html.h6 [] [ Html.text "Prev hash"]
    , p [] [ text "The response will contain the prev hash field which is the hash of the previous transaction - required to prove the authenticity of the transaction"]
    , Alert.simpleLight [] [ text """ {"prev_hash": "hash-of-prev-transaction" ...}""" ]
    , hr [] []
    , Html.h6 [] [ Html.text "Signing a Sender"]
    , p [] [ text "To create a transaction that will be accepted by the node you have to sign it with your private key (signing happens inside Senders). A typical usage pattern is to first create an unsigned transaction using the API which will return the original transaction but with an Id and prev hash and then use this to create a signed transaction and send it via this API call. See the help with signing page on the wiki." ]
    , Alert.simpleLight [] [ text """ {"sign_r": "some-signing-r", "sign_s":"some-signing-s" ...}""" ]
    , hr [] []
   ]
