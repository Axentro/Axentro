module Messages exposing (..)

import Bootstrap.Navbar as Navbar
import Http
import Navigation exposing (Location)

type alias Url = String
type Method = GET | POST


type Msg
    = UrlChange Location
    | NavMsg Navbar.State
    | RunApiCall Method Url
    | RunApiCallResponse (Result Http.Error String)
    | SetApiUrl Page String


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

    | ApiAddressTransactions
    | ApiAddressConfirmed
    | ApiAddressConfirmedToken
    | ApiAddressUnconfirmed
    | ApiAddressUnconfirmedToken

    | ApiDomainTransactions
    | ApiDomainConfirmed
    | ApiDomainConfirmedToken
    | ApiDomainUnconfirmed
    | ApiDomainUnconfirmedToken