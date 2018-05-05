module Messages exposing (..)

import Bootstrap.Navbar as Navbar
import Navigation exposing (Location)

type Msg
    = UrlChange Location
    | NavMsg Navbar.State

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