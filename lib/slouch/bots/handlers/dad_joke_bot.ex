defmodule Slouch.Bots.Handlers.DadJokeBot do
  @behaviour Slouch.Bots.Handler

  require Logger

  alias Slouch.Bots.Responder

  @jokes [
    "Why do programmers prefer dark mode? Because light attracts bugs.",
    "I told my wife she was drawing her eyebrows too high. She looked surprised.",
    "What do you call a fake noodle? An impasta.",
    "I'm reading a book about anti-gravity. It's impossible to put down.",
    "Why don't scientists trust atoms? Because they make up everything.",
    "Did you hear about the mathematician who's afraid of negative numbers? He'll stop at nothing to avoid them.",
    "Why did the scarecrow win an award? He was outstanding in his field.",
    "I used to hate facial hair, but then it grew on me.",
    "What do you call a bear with no teeth? A gummy bear.",
    "I'm on a seafood diet. I see food and I eat it.",
    "Why don't eggs tell jokes? They'd crack each other up.",
    "What did the ocean say to the beach? Nothing, it just waved.",
    "Why did the bicycle fall over? Because it was two-tired.",
    "I wouldn't buy anything with velcro. It's a total rip-off.",
    "What do you call a dog that does magic tricks? A Labracadabrador.",
    "Why couldn't the leopard play hide and seek? Because he was always spotted.",
    "I got fired from the calendar factory. All I did was take a day off.",
    "What do you call a sleeping dinosaur? A dino-snore.",
    "Why did the coffee file a police report? It got mugged.",
    "I used to play piano by ear, but now I use my hands.",
    "What do you call cheese that isn't yours? Nacho cheese.",
    "Why can't you give Elsa a balloon? Because she'll let it go.",
    "What did the janitor say when he jumped out of the closet? Supplies!",
    "How does a penguin build its house? Igloos it together.",
    "Why do cows have hooves instead of feet? Because they lactose.",
    "I just broke up with my console. Now it's my ex-box. Turns out it wasn't the One."
  ]

  @keywords ["joke", "funny", "laugh", "lol"]

  @impl true
  def handle_mention(message, channel, bot) do
    joke = Enum.random(@jokes)

    reply = Responder.post_reply(joke, message, channel, bot)
    Responder.add_reaction("😂", reply, bot)
    Responder.record_activity(bot)
    :ok
  end

  @impl true
  def handle_keyword(message, channel, bot, _matched_keyword) do
    if :rand.uniform(5) == 1 do
      joke = Enum.random(@jokes)

      reply = Responder.post_reply("Did someone say something funny? 😏\n\n#{joke}", message, channel, bot)
      Responder.add_reaction("😂", reply, bot)
      Responder.record_activity(bot)
    end

    :ok
  end

  def keywords, do: @keywords
end
