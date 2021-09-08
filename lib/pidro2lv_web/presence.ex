defmodule Pidro2lvWeb.Presence do
  use Phoenix.Presence,
    otp_app: :pidro2lv,
    pubsub_server: Pidro2lv.PubSub
end
