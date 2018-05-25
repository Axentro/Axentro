module Views.ApiOverview exposing (..)

import Html exposing (..)
import Html.Attributes exposing (href)
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
import Messages exposing (Msg(..))


pageApiOverview : Model -> List (Html Msg)
pageApiOverview model =
    [ br [] []
    , Card.config [ Card.outlineDark ]
        |> Card.headerH4 [] [ text "API Overview" ]
        |> Card.block []
            [ Block.text [] [ text "The following information gives an overview of the SushiChain API" ]
            ]
        |> Card.view
    , hr [] []
    , Grid.row [] [ Grid.col [] overviewBlockChainSection ]
    , Grid.row [] [ Grid.col [] overviewBlockSection ]
    , Grid.row [] [ Grid.col [] overviewTransactionSection ]
    , Grid.row [] [ Grid.col [] overviewAddressSection ]
    , Grid.row [] [ Grid.col [] overviewDomainSection ]
    , Grid.row [] [ Grid.col [] overviewScarsSection ]
    , Grid.row [] [ Grid.col [] overviewTokensSection ]
    , Grid.row [] [ Grid.col [] overviewNodeSection ]
    ]


overviewBlockChainSection =
    [ h3 [] [ text "Blockchain" ]
    , apiOverviewTable
        (Table.tbody []
            [ Table.tr []
                [ Table.td [] [ Html.text "GET" ]
                , Table.td [] [ a [ href "#api-blockchain" ] [ Html.text "api/v1/blockchain" ] ]
                , Table.td [] [ Html.text "full blockchain" ]
                ]
            , Table.tr []
                [ Table.td [] [ Html.text "GET" ]
                , Table.td [] [ a [ href "#api-blockchain-header" ] [ Html.text "api/v1/blockchain/header" ] ]
                , Table.td [] [ Html.text "blockchain headers" ]
                ]
            , Table.tr []
                [ Table.td [] [ Html.text "GET" ]
                , Table.td [] [ a [ href "#api-blockchain-size" ] [ Html.text "api/v1/blockchain/size" ] ]
                , Table.td [] [ Html.text "blockchain size" ]
                ]
            ]
        )
    ]


overviewBlockSection =
    [ hr [] []
    , h3 [] [ text "Block" ]
    , apiOverviewTable
        (Table.tbody []
            [ Table.tr []
                [ Table.td [] [ Html.text "GET" ]
                , Table.td [] [ a [ href "#api-block" ] [ Html.text "api/v1/block{:index}" ] ]
                , Table.td [] [ Html.text "full block at index" ]
                ]
            , Table.tr []
                [ Table.td [] [ Html.text "GET" ]
                , Table.td [] [ a [ href "#api-block-header" ] [ Html.text "api/v1/block/{:index}/header" ] ]
                , Table.td [] [ Html.text "block header at index" ]
                ]
            , Table.tr []
                [ Table.td [] [ Html.text "GET" ]
                , Table.td [] [ a [ href "#api-block-transactions" ] [ Html.text "api/v1/block/{:index}/transactions" ] ]
                , Table.td [] [ Html.text "transactions in block" ]
                ]
            ]
        )
    ]


overviewTransactionSection =
    [ hr [] []
    , h3 [] [ text "Transaction" ]
    , apiOverviewTable
        (Table.tbody []
            [ Table.tr []
                [ Table.td [] [ Html.text "GET" ]
                , Table.td [] [ a [ href "#api-transaction" ] [ Html.text "api/v1/transaction{:id}" ] ]
                , Table.td [] [ Html.text "transaction for supplied transaction id" ]
                ]
            , Table.tr []
                [ Table.td [] [ Html.text "GET" ]
                , Table.td [] [ a [ href "#api-transaction-block" ] [ Html.text "api/v1/transaction/{:id}/block" ] ]
                , Table.td [] [ Html.text "block containing transaction id" ]
                ]
            , Table.tr []
                [ Table.td [] [ Html.text "GET" ]
                , Table.td [] [ a [ href "#api-transaction-block-header" ] [ Html.text "api/v1/transaction/{:id}/block/header" ] ]
                , Table.td [] [ Html.text "header for block containing transaction id" ]
                ]
            , Table.tr []
                [ Table.td [] [ Html.text "GET" ]
                , Table.td [] [ a [ href "#api-transaction-confirmations" ] [ Html.text "api/v1/transaction/{:id}/confirmations" ] ]
                , Table.td [] [ Html.text "number of confirmations for transaction" ]
                ]
            , Table.tr []
                [ Table.td [] [ Html.text "GET" ]
                , Table.td [] [ a [ href "#api-transaction-fees" ] [ Html.text "api/v1/transaction/fees" ] ]
                , Table.td [] [ Html.text "get transaction fees" ]
                ]
            , Table.tr []
                [ Table.td [] [ Html.text "POST" ]
                , Table.td [] [ a [ href "#api-transaction-create-unsigned" ] [ Html.text "api/v1/transaction/unsigned" ] ]
                , Table.td [] [ Html.text "create an unsigned transaction" ]
                ]
            , Table.tr []
                [ Table.td [] [ Html.text "POST" ]
                , Table.td [] [ a [ href "#api-transaction-create" ] [ Html.text "api/v1/transaction" ] ]
                , Table.td [] [ Html.text "create and broadcast a signed transaction" ]
                ]
            ]
        )
    ]


overviewAddressSection =
    [ hr [] []
    , h3 [] [ text "Address" ]
    , apiOverviewTable
        (Table.tbody []
            [ Table.tr []
                [ Table.td [] [ Html.text "GET" ]
                , Table.td [] [ a [ href "#api-address-transactions" ] [ Html.text "api/v1/address/{:address}/transactions" ] ]
                , Table.td [] [ Html.text "transactions for address" ]
                ]
            , Table.tr []
                [ Table.td [] [ Html.text "GET" ]
                , Table.td [] [ a [ href "#api-address-amount" ] [ Html.text "api/v1/address/{:address}" ] ]
                , Table.td [] [ Html.text "amount for address for all tokens" ]
                ]
            , Table.tr []
                [ Table.td [] [ Html.text "GET" ]
                , Table.td [] [ a [ href "#api-address-amount-token" ] [ Html.text "api/v1/address/{:address}/token/{:token}" ] ]
                , Table.td [] [ Html.text "amount for address for specified token" ]
                ]
            ]
        )
    ]


overviewDomainSection =
    [ hr [] []
    , h3 [] [ text "Domain" ]
    , apiOverviewTable
        (Table.tbody []
            [ Table.tr []
                [ Table.td [] [ Html.text "GET" ]
                , Table.td [] [ a [ href "#api-domain-transactions" ] [ Html.text "api/v1/domain/{:domain}/transactions" ] ]
                , Table.td [] [ Html.text "transactions for domain" ]
                ]
            , Table.tr []
                [ Table.td [] [ Html.text "GET" ]
                , Table.td [] [ a [ href "#api-domain-amount" ] [ Html.text "api/v1/domain/{:domain}" ] ]
                , Table.td [] [ Html.text "amount for domain for all tokens" ]
                ]
            , Table.tr []
                [ Table.td [] [ Html.text "GET" ]
                , Table.td [] [ a [ href "#api-domain-amount-token" ] [ Html.text "api/v1/domain/{:domain}/token/{:token}" ] ]
                , Table.td [] [ Html.text "amount for domain for specified token" ]
                ]
            ]
        )
    ]


overviewScarsSection =
    [ hr [] []
    , h3 [] [ text "SCARS (Human readable addresses)" ]
    , apiOverviewTable
        (Table.tbody []
            [ Table.tr []
                [ Table.td [] [ Html.text "GET" ]
                , Table.td [] [ a [ href "#api-scars-sales" ] [ Html.text "api/v1/scars/sales" ] ]
                , Table.td [] [ Html.text "get all scars domains for sale" ]
                ]
            , Table.tr []
                [ Table.td [] [ Html.text "GET" ]
                , Table.td [] [ a [ href "#api-scars-domain" ] [ Html.text "api/v1/scars/{:domain}" ] ]
                , Table.td [] [ Html.text "get the status of the domain" ]
                ]
            ]
        )
    ]


overviewTokensSection =
    [ hr [] []
    , h3 [] [ text "Tokens" ]
    , apiOverviewTable
        (Table.tbody []
            [ Table.tr []
                [ Table.td [] [ Html.text "GET" ]
                , Table.td [] [ a [ href "#api-token-list" ] [ Html.text "api/v1/tokens" ] ]
                , Table.td [] [ Html.text "list of tokens" ]
                ]
            ]
        )
    ]


overviewNodeSection =
    [ hr [] []
    , h3 [] [ text "Node" ]
    , apiOverviewTable
        (Table.tbody []
            [ Table.tr []
                [ Table.td [] [ Html.text "GET" ]
                , Table.td [] [ a [ href "#api-node" ] [ Html.text "api/v1/node" ] ]
                , Table.td [] [ Html.text "show current node information" ]
                ]
            , Table.tr []
                [ Table.td [] [ Html.text "GET" ]
                , Table.td [] [ a [ href "#api-node-id" ] [ Html.text "api/v1/node/{:id}" ] ]
                , Table.td [] [ Html.text "show information for the specified node id" ]
                ]
            , Table.tr []
                [ Table.td [] [ Html.text "GET" ]
                , Table.td [] [ a [ href "#api-nodes" ] [ Html.text "api/v1/nodes" ] ]
                , Table.td [] [ Html.text "show connected nodes information" ]
                ]
            ]
        )
    ]


apiOverviewTable : Table.TBody msg -> Html.Html msg
apiOverviewTable tableBody =
    Table.table
        { options = [ Table.bordered ]
        , thead = apiOverviewThead []
        , tbody = tableBody
        }


apiOverviewThead : List (Table.TableHeadOption msg) -> Table.THead msg
apiOverviewThead options =
    Table.thead options
        [ Table.tr []
            [ Table.th [] [ Html.text "Method" ]
            , Table.th [] [ Html.text "Url" ]
            , Table.th [] [ Html.text "Notes" ]
            ]
        ]
