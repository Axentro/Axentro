module Views.ApiTransactionCreateUnsigned exposing (..)

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


pageApiTransactionCreateUnsigned : Model -> List (Html Msg)
pageApiTransactionCreateUnsigned model =
    let
        description =
            div [] [ Html.text "Creates an unsigned transaction with the supplied data (which can be used to make a signed transaction) - The transaction is returned in the response with a generated Id which can then be signed and used with the create (signed) transaction API call." ]

        ex = """{"status":"success","result":{"id":"ea4fb45c5b0e12a959e65435cbcc29e52fcab64b4684c5c546ea044f8da927e4","action":"send","senders":[{"address":"VDBkYWQxZjZlZjllOTAzYzNiODQ0NmZkZTI4NDBhYmMzYjUxYThjM2E1ZjNkODlj","public_key":"48c45b7e45cd415187216452fa22523e002ca042c2bd7205484f29201c3d5806f90e7aeebad37e3fbe01286c25d4027d3f3fec7b5647eff33c07ebd287b57242","amount":5000,"fee":1}],"recipients":[{"address":"VDBlY2I4ZjA5MTUxOWE0MTIwNTRmZjlhYTM1YjYxMjcwNjM1YzcxYjlkMDZhZDUx","amount":5000}],"message":"","token":"SUPERCOOL","prev_hash":"0","sign_r":"0","sign_s":"0"}}"""
    in
        [ br [] []
        , Grid.row []
            [ apiLeftNav ApiTransactionCreateUnsigned
            , Grid.col [ Col.md9 ]
                [ documentation ApiTransactionCreateUnsigned model.apiUrlT6 (Just model.apiBody) model.apiResponse "Transaction Create Unsigned" description "POST" "api/v1/transaction/unsigned" (Just requestDescription) Nothing """curl -X POST -H 'Content-Type: application/json' -d '{"action": "send","senders": [{"address": "VDBkYWQxZjZlZjllOTAzYzNiODQ0NmZkZTI4NDBhYmMzYjUxYThjM2E1ZjNkODlj","public_key": "48c45b7e45cd415187216452fa22523e002ca042c2bd7205484f29201c3d5806f90e7aeebad37e3fbe01286c25d4027d3f3fec7b5647eff33c07ebd287b57242","amount": 5000,"fee": 1}],"recipients": [{"address": "VDBlY2I4ZjA5MTUxOWE0MTIwNTRmZjlhYTM1YjYxMjcwNjM1YzcxYjlkMDZhZDUx","amount": 5000}],"message": "","token": "SUPERCOOL"}' http://localhost:3000/api/v1/transaction/unsigned""" ex model.error
                ]
            ]
        ]

requestDescription : Html Msg
requestDescription =
   div [] [
    hr [] []
    , Html.h5 [] [ Html.text "Post Body"]
    , p [] [ text "The post body is made up of the following mandatory fields:"]
    , ul [] [
     li [] [ text "action"]
     , li [] [ text "senders"]
     , li [] [ text "recipients"]
     , li [] [ text "message"]
     , li [] [ text "token"]
    ]
    , hr [] []
    , Html.h6 [] [ Html.text "Action"]
    , p [] [ text "action is the type of action to perform - e.g send - is when you want to send some tokens to an address. Send is the most common but there are others like create_token etc as well as those used in scars. Also users can create their own actions as part of building dApps."]
    , Alert.simpleLight [] [ text """ {"action":"send" ...} """ ]
    , hr [] []
    , Html.h6 [] [ Html.text "Senders"]
    , p [] [ text "This is information about where a payment or action originates - e.g. the address from which to send tokens from. It's made up of an address, amount, fee and public key. It's a list of senders but generally there is only one"]
    , Alert.simpleLight [] [ text """ {"senders": [{"address": "the-address", "amount":1000, "fee":1, "public_key":"the-public-key"}] ...}""" ]
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
   ]