module Messages exposing (..)

type ViewState = EntryView
               | CreateNewWallet1
               | CreateNewWallet2

type Msg = NoOp
          | ChangeViewState ViewState
          | SetWalletName String
          | SetWalletPassword String
          | SetWalletPasswordConfirm String
          | Acknowledge1


