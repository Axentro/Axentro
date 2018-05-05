module Messages exposing (..)

import Bootstrap.Navbar as Navbar
import Navigation exposing (Location)

type Msg
    = UrlChange Location
    | NavMsg Navbar.State
    | CloseModal
    | ShowModal

type Page
    = Home
    | GettingStarted
    | Modules
    | NotFound
    | ApiOverview