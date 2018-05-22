module Views.ApiLeftNav exposing (..)

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
import Messages exposing (Msg(..), Page(..))


apiLeftNav : Page -> Grid.Column Msg
apiLeftNav page =
    Grid.col [ Col.md3 ]
        [ hr [] []
        , h5 [] [ text "Blockchain" ]
        , link ApiBlockchain "#api-blockchain" "blockchain" page
        , link ApiBlockchainHeader "#api-blockchain-header" "blockchain/header" page
        , link ApiBlockchainSize "#api-blockchain-size" "blockchain/size" page
        , hr [] []
        , h5 [] [ text "Block" ]
        , link ApiBlock "#api-block" "block" page
        , link ApiBlockHeader "#api-block-header" "block/header" page
        , link ApiBlockTransactions "#api-block-transactions" "block/transactions" page
        , hr [] []
        , h5 [] [ text "Transaction" ]
        , link ApiTransaction "#api-transaction" "transaction" page
        , link ApiTransactionBlock "#api-transaction-block" "transaction/block" page
        , link ApiTransactionBlockHeader "#api-transaction-block-header" "transaction/block/header" page
        , link ApiTransactionConfirmations "#api-transaction-confirmations" "transaction/confirmations" page
        , link ApiTransactionFees "#api-transaction-fees" "transaction/fees" page
        , link ApiTransactionCreateUnsigned "#api-transaction-create-unsigned" "transaction/create/unsigned" page
        , link ApiTransactionCreate "#api-transaction-create" "transaction/create" page
        , hr [] []
        , h5 [] [ text "Address" ]
        , link ApiAddressTransactions "#api-address-transactions" "address/transactions" page
        , link ApiAddressAmount "#api-address-amount" "address/amount" page
        , link ApiAddressAmountToken "#api-address-amount-token" "address/amount/token" page
        , hr [] []
        , h5 [] [ text "Domain" ]
        , link ApiDomainTransactions "#api-domain-transactions" "domain/transactions" page
        , link ApiDomainAmount "#api-domain-amount" "domain/amount" page
        , link ApiDomainAmountToken "#api-domain-amount-token" "domain/amount/token" page
        , hr [] []
        , h5 [] [ text "SCARS" ]
        , link ApiScarsSales "#api-scars-sales" "scars/sales" page
        , link ApiScarsDomain "#api-scars-domain" "scars/domain" page
        , hr [] []
        , h5 [] [ text "Tokens" ]
        , link ApiTokenList "#api-token-list" "tokens/list" page
        ]


link : Page -> String -> String -> Page -> Html Msg
link thisPage url desc currentPage =
    if thisPage == currentPage then
        div [] [ div [ class "badge badge-secondary" ] [ a [ style [ ( "color", "white" ) ], href url ] [ text desc ] ] ]
    else
        div [] [ div [] [ a [ href url ] [ text desc ] ] ]
