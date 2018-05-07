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
    ]


overviewBlockChainSection =
    [ h3 [] [ text "Blockchain" ]
    , apiOverviewTable
        (Table.tbody []
            [ Table.tr []
                [ Table.td [] [ Html.text "GET" ]
                , Table.td [] [ a [ href "#api-blockchain" ] [ Html.text "v1/blockchain" ] ]
                , Table.td [] [ Html.text "full blockchain" ]
                ]
            , Table.tr []
                [ Table.td [] [ Html.text "GET" ]
                , Table.td [] [ a [ href "#api-blockchain-header" ] [ Html.text "v1/blockchain/header" ] ]
                , Table.td [] [ Html.text "blockchain headers" ]
                ]
            , Table.tr []
                [ Table.td [] [ Html.text "GET" ]
                , Table.td [] [ a [ href "#api-blockchain-size" ] [ Html.text "v1/blockchain/size" ] ]
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
                , Table.td [] [ a [ href "#api-block" ] [ Html.text "v1/block{:index}" ] ]
                , Table.td [] [ Html.text "full block at index" ]
                ]
            , Table.tr []
                [ Table.td [] [ Html.text "GET" ]
                , Table.td [] [ a [ href "#api-block-header" ] [ Html.text "v1/block/{:index}/header" ] ]
                , Table.td [] [ Html.text "block header at index" ]
                ]
            , Table.tr []
                [ Table.td [] [ Html.text "GET" ]
                , Table.td [] [ a [ href "#api-block-transactions" ] [ Html.text "v1/block/{:index}/transactions" ] ]
                , Table.td [] [ Html.text "transactions in block" ]
                ]
            ]
        )
    ]



--
-- [GET] v1/transaction/{:id}                        | transaction for supplied txn id
--  # [GET] v1/transaction/{:id}/block                  | full block containing txn id
--  # [GET] v1/transaction/{:id}/block/header           | block header containing txn id
--  # [GET] v1/transaction/{:id}/confirmations          | number confirmations for txn id
--  # [GET] v1/transaction/fees                         | fees
--  # [POST] v1/transaction                             | create and broadcast a transaction
--  # [POST] v1/transaction/unsigned                    | create an unsigned transaction


overviewTransactionSection =
    [ hr [] []
    , h3 [] [ text "Transaction" ]
    , apiOverviewTable
        (Table.tbody []
            [ Table.tr []
                [ Table.td [] [ Html.text "GET" ]
                , Table.td [] [ a [ href "#api-transaction" ] [ Html.text "v1/transaction{:id}" ] ]
                , Table.td [] [ Html.text "transaction for supplied transaction id" ]
                ]
            , Table.tr []
                [ Table.td [] [ Html.text "GET" ]
                , Table.td [] [ a [ href "#api-transaction-block" ] [ Html.text "v1/transaction/{:id}/block" ] ]
                , Table.td [] [ Html.text "block containing transaction id" ]
                ]
            , Table.tr []
                [ Table.td [] [ Html.text "GET" ]
                , Table.td [] [ a [ href "#api-transaction-block-header" ] [ Html.text "v1/transaction/{:id}/block/header" ] ]
                , Table.td [] [ Html.text "header for block containing transaction id" ]
                ]
            , Table.tr []
                [ Table.td [] [ Html.text "GET" ]
                , Table.td [] [ a [ href "#api-transaction-confirmations" ] [ Html.text "v1/transaction/{:id}/confirmations" ] ]
                , Table.td [] [ Html.text "number of confirmations for transaction" ]
                ]
            , Table.tr []
                [ Table.td [] [ Html.text "GET" ]
                , Table.td [] [ a [ href "#api-transaction-fees" ] [ Html.text "v1/transaction/fees" ] ]
                , Table.td [] [ Html.text "get transaction fees" ]
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
