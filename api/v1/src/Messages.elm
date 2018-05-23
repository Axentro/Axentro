module Messages exposing (..)

import Bootstrap.Navbar as Navbar
import Http
import Navigation exposing (Location)

type alias Url = String
type Method = GET | POST


type Msg
    = UrlChange Location
    | NavMsg Navbar.State
    | RunApiCall Method Url (Maybe String)
    | RunApiCallResponse (Result Http.Error String)
    | SetApiUrl Page String
    | SetApiBody String


type Page
    = GettingStarted
    | NotFound
    | ApiOverview

    | ApiBlockchain
    | ApiBlockchainHeader
    | ApiBlockchainSize
    | ApiBlock
    | ApiBlockHeader
    | ApiBlockTransactions

    | ApiTransaction
    | ApiTransactionBlock
    | ApiTransactionBlockHeader
    | ApiTransactionConfirmations
    | ApiTransactionFees
    | ApiTransactionCreateUnsigned
    | ApiTransactionCreate

    | ApiAddressTransactions
    | ApiAddressAmount
    | ApiAddressAmountToken

    | ApiDomainTransactions
    | ApiDomainAmount
    | ApiDomainAmountToken

    | ApiScarsSales
    | ApiScarsDomain

    | ApiTokenList